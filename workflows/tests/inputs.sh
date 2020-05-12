#!/bin/bash
set -euo pipefail

wdl="$1"
workflows="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows"
WOMTOOL_PATH="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/womtool-*.jar"

echo Looking for WDL script starting from the workflows folder
if [ ! -d $workflows ]; then echo ERROR: Workflows folder does not exist!; exit; fi
wdl="$( find $workflows -name "$wdl" -print -quit )"
if [ -z $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi 

set -x
java -jar $WOMTOOL_PATH inputs $wdl
set +x

set +u
echo "Save input file? (Y/n)"
read do_save

if [[ "$do_save" == "Y" || "$do_save" == "y" ]]; then
	echo "Save destination?"
	read destination
	destination=${destination%/}
	echo "Filename?"
	read filename
	filename="${filename%.json}.json"
	if [[ -z $filename ]]; then
		filename="$(basename -s .wdl ${wdl}).json"
		echo "No input detected, writing as $filename"
	fi
	echo Moving $filename to $destination
	mkdir -p $destination
	java -jar $WOMTOOL_PATH inputs $wdl > $destination/$filename
else
	echo "Not saving."
fi

