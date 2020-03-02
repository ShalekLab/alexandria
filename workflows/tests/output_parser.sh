#!/bin/bash
# Intended for tab-delimited WDL scripts which are version draft-2 and 1.0

set -euo pipefail
echo -----------------------------------------------------------------------------------------------------
# Variable initialization
wdl="$1"
output_dir="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/dummies/${wdl%.wdl}"

printf "FILE ${wdl}: BEGIN PRE-PARSING OUTPUTS TO BUILD TASK DUMMY SCRIPTS.\n\n"

in_task="false"
do_parse="false"

IFS=''
while read line; do
	
	# Strip the line of leading and trailing whitespace
	stripped_line="$( echo $line | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )"
	
	if [[ "$do_parse" == "false"  ]]; then
		if [[ "$stripped_line" == "workflow"*"{" ]]; then
			in_task="false"
			workflow="$(echo $stripped_line | sed -e 's/workflow//' -E -e 's/( |{)//g' )"
			output_dir="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/dummies/${workflow}"
			echo Identified workflow: $workflow
			echo Outputted scripts will be sent to $output_dir
		fi
		# Task name
		if [[ "$stripped_line" == "task"*"{" ]]; then
			task=$(echo $stripped_line | sed -e 's/task//' -E -e 's/( |{)//g' )
			printf "\tIdentified task: ${task}.\n"
			if [ ! -e ${output_dir}/${task}.sh ]; then
				in_task="true"
			else
				printf "\t\tTask already has existing script at ${output_dir}/${task}.sh, skipping parsing of outputs.\n"
			fi
		fi
		if [[ "$in_task" == "true" && "$stripped_line" == "output"*"{" ]]; then
			#task=$(echo $stripped_line | sed -e 's/output//' -E -e 's/( |{)//g' )
			printf "\t\tIdentified output block of ${task}.\n"
			do_parse="true"
			printf "\t\tParsing outputs of ${task}...\n"
		fi
	else
		#printf "\t\t\t${stripped_line}\n"
		if [[ "$stripped_line" == "}"* ]]; then
			do_parse="false"
			in_task="false"
		else
			LHS="$( echo $stripped_line | sed 's/=.*//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )"
			RHS="$( echo $stripped_line | sed 's/.*=//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )"
			printf "\t\t\t\t${LHS} = ${RHS}\n"
			if [[ "$LHS" == *"File"* || "$LHS" == *"String"* || "$LHS" == *"Int"* || "$LHS" == *"Boolean"* ]]; then
				printf "\t\t\t\t\tLooking for apostrophes on right-hand side...\n"
				# Look for apostrophes
				if [[ "$RHS" == *"\""*"\""* || "$RHS" == *"'"*"'"* ]]; then
					printf "\t\t\t\t\tLooking for the name enclosed in the apostrophes...\n"
					# Get the name between the single/double apostrophes
					name="$( echo $RHS | sed 's/.*\"\(.*\)\".*/\1/' | sed "s/.*'\(.*\)'.*/\1/" | sed 's/\*/asterisk/g')"
					printf "\t\t\t\t\tName: ${name}\n"
					mkdir -p $output_dir
					echo "echo $name >> $name" >> ${output_dir}/${task}.sh 
					printf "\t\t\t\t\tAdded to ${output_dir}/${task}.sh.\n"
				fi
			fi
		fi
	fi
done < $wdl
echo FILE ${wdl}: COMPLETED PARSING OF OUTPUTS