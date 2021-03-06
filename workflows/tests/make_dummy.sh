#!/bin/bash
# Intended for tab-delimited WDL scripts which are version draft-2 and 1.0

set -euo pipefail

# Variable initialization
wdl="$1"
workflows="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows"
if [ ! -d $workflows ]; then echo ERROR: Workflows folder does not exist!; exit; fi

echo Looking for WDL script starting from the workflows folder
wdl="$( find $workflows -name "$wdl" )"
if [ -z $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi 

bash output_parser.sh $wdl

echo -----------------------------------------------------------------------------------------------------
printf "FILE ${wdl}: BEGIN PARSING FILE TO INSERT SCRIPTS IN COMMAND BLOCKS\n\n"

basename="$(basename -s .wdl $wdl)"
output_dir="${workflows}/tests/dummies/${basename}"
mkdir -p $output_dir
wdl_dummy="${basename}_dummy.wdl"

# If the WDL_dummy file already exists, delete it and start from scratch
if [[ -e ${output_dir}/${wdl_dummy} ]]; then
	if [[ "$( head -n 1 ${output_dir}/${wdl_dummy} )" == "#OVERRIDE" ]]; then
		echo FILE: OVERRIDE DETECTED, LEAVING AS IS.
		exit
	else
		trash ${output_dir}/${wdl_dummy}
		echo Trashed existing $wdl_dummy and making new dummy from scratch!
	fi
fi
echo Dummy will be located at ${output_dir}/${wdl_dummy} 

do_write="true"
operator=""
stripped_line=""
task=""
while IFS='' read -r line; do

	# Strip the line of leading and trailing whitespace
	stripped_line="$( echo $line | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )"
	indentation=$(echo "$line" | sed -e 's/[[:space:]]*$//' | awk -F '\t' '{print NF-1}')
	#echo "$line" $indentation

	### Identify certain keywords
	# Import statements
	if [[ "$stripped_line" == "import \""* ]]; then
		# Strip firecloud methods respository https junk, replace with local.
		line="$(echo $stripped_line | sed -e 's/https:.*://' -e 's/\/versions.*descriptor//' )"
		import_name="$( basename -s .wdl $( echo $line | sed -e 's/import \"//' -e 's/\".*//' ) )"
		import_dummy="${import_name%.wdl}_dummy.wdl"
		line="$(echo $line | sed -e "s:\".*\":\"${workflows}/tests/dummies/${import_name}/${import_dummy}\":" )"
		# Recurse on the import file.
		# If this file does not exist, the program will crash.
		import_file=$( find $workflows -name "${import_name%.wdl}.wdl")
		if [ -z $import_file ]; then echo ERROR: import file $import_file does not exist!; exit; fi
		import_file="$(basename $import_file)"
		printf "Recursing on subworkflow $import_file ...\n"
		bash make_dummy.sh $import_file
		echo -----------------------------------------------------------------------------------------------------
		printf "FILE ${wdl}: RETURNED TO WORKFLOW FROM CHILD.\n\n"
	fi
	# Workflow name
	if [[ "$stripped_line" == "workflow"*"{" ]]; then
		workflow="$(echo $stripped_line | sed -e 's/workflow//' -E -e 's/( |{)//g' )"
		echo Identified workflow: $workflow
		echo Outputted scripts will be read from $output_dir
	fi
	# Task name
	if [[ "$stripped_line" == "task"*"{" ]]; then
		task=$(echo $stripped_line | sed -e 's/task//' -E -e 's/( |{)//g' )
		echo Identified task: $task
	fi
	
	# If command block closing operator is encountered, reset do_write to true.
	if [[ "$do_write" == "false" && "$stripped_line" == "${operator}" ]]; then
		printf "\tEncountered closing operator of the block.\n"
		do_write="true"
	elif [[ "$stripped_line" == *"command"* ]]; then
		
		printf "\tEncountered the command block of $task.\n"
		# Print command keyword line to file.
		echo "$line" >> ${output_dir}/$wdl_dummy
		
		printf "\tIdentifying the command block operator..."
		# Determine the type of operator the command block uses.
		if [[ "$stripped_line" == *"<<<"* ]]; then
			operator=">>>"
		elif [[ "$stripped_line" == *"{"* ]]; then
			operator="}"
		else
			echo "No command starting operator ( \"<<<\", \"{\") was detected after \"command\" keyword."
			exit
		fi
		printf " Operator is $operator\n"

		# Insert dummy bash into the command block
		# Ensure that the script exists
		if [ ! -e ${output_dir}/${task}.sh ]; then
			echo ERROR! could not locate task script! && exit
		fi
		# Determine what the indentation of the script needs to be
		script_indentation=2
		#script_indentation=$(( $indentation + 1 ))
		tabs="$( seq  -f "\t" -s '' ${script_indentation} )"
		#tabs="$( printf "%0.s\\t" {1..$script_indentation} )" # Doesn't work with bash 3.2
		# Prefix the file with tab indentation and insert into the command block.
		printf "\tInserting script into $task command block...\n"
		sed "s/^/${tabs}/" ${output_dir}/${task}.sh >> ${output_dir}/$wdl_dummy
		
		# Set do_write to false, will be set to true when operator is encountered.
		do_write="false"
	elif [[ "$stripped_line" == *"runtime"* ]]; then
		printf "\tEncountered the runtime block of $task.\n"
		echo "$line" >> ${output_dir}/$wdl_dummy
		
		script_indentation=2
		#script_indentation=$(( $indentation + 1 ))
		tabs="$( seq  -f "\t" -s '' ${script_indentation} )"
		#tabs="$( printf "%0.s\\t" {1..$script_indentation} )" # Doesn't work with bash 3.2
		#echo SCRIPT INDENTATION $script_indentation TABS:$tabs
		if [ -e "${output_dir}/${task}_runtime.txt" ]; then 
			printf "\tInserting script into $task runtime block...\n"
			sed "s/^/${tabs}/" ${output_dir}/${task}_runtime.txt >> ${output_dir}/$wdl_dummy
		else
			printf "\tNo runtime text file was found for $task, inserting ubuntu:latest for docker.\n"
			printf "${tabs}docker: \"ubuntu:latest\"\n" >> ${output_dir}/$wdl_dummy
		fi
		operator="}"
		do_write="false"
	fi
	# If true, write the line provided that it is not a comment (Comments can contain harmful characters)
	if [[ "$do_write" == "true" && "${stripped_line:0:1}" != "#" ]]; then
		echo "$line" >> ${output_dir}/$wdl_dummy
	fi
done < $wdl

if [[ $indentation -gt 0 ]]; then # && "$(tail -c 1 $wdl)" ==  ]]; then
	printf "EOF was on an indented line (prematurely) due to a quirk with bash.\n"
	printf "Appending a final bracket, please verify that this is correct!\n"
	echo "}" >> ${output_dir}/$wdl_dummy
fi

echo FILE ${wdl}: COMPLETED DUMMY: ${output_dir}/${wdl_dummy}
echo Please run ./validate.sh ${wdl_dummy}