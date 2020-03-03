#!/bin/bash
wdl="$1"
inputs="$2"
workflows="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows"

CROMWELL_PATH="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/cromwell-*.jar"

set -euo pipefail

echo Looking for WDL script starting from the workflows folder
if [ ! -d $workflows ]; then echo ERROR: Dummies folder does not exist!; exit; fi
wdl="$( find $workflows -name "${wdl}" )"
if [ -z $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi 

if [ -z $inputs ]; then
	inputs="${wdl%.wdl}.json"
	#inputs="${inputs%_dummy}.json"
fi

set -x
java -jar ${CROMWELL_PATH} run $wdl --inputs $inputs