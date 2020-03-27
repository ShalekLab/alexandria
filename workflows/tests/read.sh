#!/bin/bash
set -euo pipefail

identify_indentation="true"
indentation_type="None"

while IFS= read -r line; do

	stripped_line="$( echo $line | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )"

	if [[ "$identify_indentation" == "true" ]]; then
		echo "In identify_indentation"
		if [[ "$line" == "\t"* ]]; then
			indentation_type="\t"
			echo "INDENTATION_TYPE IS TABS"
		elif [[ "$line" == "    "* ]]; then
			indentation_type="    "
			echo "INDENTATION_TYPE IS 4-SPACE"
		elif [[ "$line" == "  "* ]]; then
			indentation_type="  "
			echo "INDENTATION_TYPE IS 2-SPACE"
		else
			echo ERROR: Could not determine indentation of block
		fi
	fi

	if [[ "$stripped_line" == *"command"* ]]; then
		if [[ "$identify_indentation" == "true" ]]; then	
			echo "ERROR: FAILED TO IDENTIFY INDENTATION BEFORE COMMAND BLOCK"
			exit
		fi
	fi

	#indentation=$(echo "$line" | sed -e 's/[[:space:]]*$//' | awk -F '\t' '{print NF-1}')
	indentation=$(echo "$line" | sed -e 's/[[:space:]]*$//' | awk -F "$indentation_type" '{print NF-1}' )
	script_indentation=$(( $indentation + 1 ))
	indents="$( seq -f "\t" -s '' ${script_indentation} )"
	#tabs=$( printf "%0.s\\t" {1..$script_indentation} )
	echo "$line" INDENTATION: $indentation SCRIPT INDENTATION $script_indentation INDENTS:$indents

done < <( head -n 100 ../other/drop-seq/dropseq_prepare_fastq.wdl )
