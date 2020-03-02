#!/bin/bash
# Intended for tab-delimited WDL scripts which are version draft-2 and 1.0

set -euo pipefail

# Variable initialization
wdl="$1"
workflows="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows"

echo Looking for WDL script starting from the workflows folder
if [ ! -d $workflows ]; then echo ERROR: Workflows folder does not exist!; exit; fi
wdl="$( find $workflows -name "$wdl" )"
if [ -z $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi 

bash output_parser.sh $wdl

echo -----------------------------------------------------------------------------------------------------
printf "FILE ${wdl}: BEGIN PARSING FILE TO INSERT SCRIPTS IN COMMAND BLOCKS\n\n"

wdl_dummy="${wdl%.wdl}_dummy.wdl"
#output_dir="dummies/${wdl%.wdl}"
#output_dir="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/dummies/${wdl%.wdl}"
output_dir="${wdl%.wdl}"

# If the WDL_dummy file already exists, delete it and start from scratch
if [ -e ${output_dir}/$wdl_dummy ]; then
	rm ${output_dir}/$wdl_dummy
	echo Removed $wdl_dummy and making new dummy from scratch!
fi

do_write="true"
operator=""
stripped_line=""
task=""
indentation=0
IFS=''
while read line; do
	
	# Strip the line of leading and trailing whitespace
	stripped_line="$( echo $line | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )"

	### Identify certain keywords
	# Import statements
	if [[ "$stripped_line" == "import \""* ]]; then
		# Strip firecloud methods respository https junk, replace with local.
		line="$(echo $stripped_line | sed -e 's/https:.*://' -e 's/\/versions.*descriptor/_dummy.wdl/' )"
		# Determine the import filename.
		import_file="$( echo $line | sed -e 's/import \"//' -e 's/_dummy//' -e 's/\".*//' )"
		import_dummy="${import_file%.wdl}_dummy.wdl"
		line="$(echo $line | sed -e "s/${import_dummy}/\.\.\/${import_file%.wdl}\/${import_dummy}/" )"
		# Recurse on the import file.
		# If this file does not exist, the program will crash.
		printf "Recursing on subworkflow $import_file ...\n"
		bash make_dummy.sh $import_file
		echo -----------------------------------------------------------------------------------------------------
		printf "FILE ${wdl}: RETURNED TO WORKFLOW FROM CHILD.\n\n"
	fi
	# Workflow name
	if [[ "$stripped_line" == "workflow"*"{" ]]; then
		workflow="$(echo $stripped_line | sed -e 's/workflow//' -E -e 's/( |{)//g' )"
		output_dir="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/dummies/${workflow}"
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
		printf "\tEncountered closing operator of command block.\n"
		do_write="true"
	elif [[ "$stripped_line" == *"command"* ]]; then
		
		printf "\tEncountered the command block of $task.\n"
		# Print command keyword line to file.
		#printf "$line\n" >> ${output_dir}/$wdl_dummy
		printf "$line\n" >> $wdl_dummy
		
		printf "\tIdentifying the command block operator..."
		# Determine the type of operator the command block uses.
		if [[ "$stripped_line" == *"<<<"* ]]; then
			operator=">>>"
		elif [[ "$stripped_line" == *"{"* ]]; then
			operator="}"
		else
			echo "No command starting operator ( \"<<<\", \"{\") was detected after \"command\" keyword." && exit
		fi
		printf " Operator is $operator\n"

		# Insert dummy bash into the command block
		# Determine what the indentation of the script needs to be
		indentation=$(( $(echo $line | sed -e 's/[[:space:]]*$//' | awk -F '\t' '{print NF-1}') + 1 ))
		tabs="$( seq  -f "\t" -s '' ${indentation} )"
		# If the script does not exist, create it
		if [ ! -e ${output_dir}/${task}.sh ]; then
			printf "\tMaking a minimal dummy script /${workflow}/${task}.sh for $task command block...\n"
			echo "echo Hello $task" >> ${output_dir}/${task}.sh
		fi
		# Prefix the file with tab indentation and insert into the command block.
		printf "\tInserting script into $task command block...\n"
		sed "s/^/${tabs}/" ${output_dir}/${task}.sh >> $wdl_dummy
		
		# Set do_write to false, will be set to true when operator is encountered.
		do_write="false"
	fi
	# If true, write the line provided that it is not a comment (Comments can contain harmful characters)
	if [[ "$do_write" == "true" && "${stripped_line:0:1}" != "#" ]]; then
		#printf "$line\n" >> ${output_dir}/$wdl_dummy
		printf "$line\n" >> $wdl_dummy
	fi
done < $wdl

echo FILE ${wdl}: COMPLETED DUMMY CREATION!