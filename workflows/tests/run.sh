#!/bin/bash
set -euo pipefail

wdl="$1"
inputs="${2%.json}.json"
workflows="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/"

CROMWELL_PATH="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/cromwell-*.jar"
CROMWELL_CONFIG="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/cromwell.conf"
WORKFLOW_OPTIONS="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/cromwell_workflow_options.json"

#if [[ "$wdl" == *".wdl" ]]; then
#	echo Looking for WDL script at relative path $wdl
#	if [ ! -e $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi
#else
#	echo Looking for WDL script at dummies/$wdl folder
#	if [ ! -d dummies/$wdl ]; then echo ERROR: Folder does not exist!; exit; fi
#	wdl="$( find dummies/$wdl -name "${wdl}_dummy.wdl" )"
#	if [ -z $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi 
#fi

echo Looking for WDL script starting from the workflows folder
if [ ! -d $workflows ]; then echo ERROR: Dummies folder does not exist!; exit; fi
wdl="$( find $workflows -name "${wdl}" )"
if [ -z $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi 

: '
if [ ! -z $inputs ]; then
	inputs="${wdl%.wdl}.json"
	if [ ! -e $inputs ]; then echo ERROR: input JSON does not exist!; exit; fi
elif [[ "$inputs" == *".json" ]];
	echo Looking for input JSON at relative path $inputs
	if [ ! -e $inputs ]; then echo ERROR: input JSON does not exist!; exit; fi
else # $wdl == $inputs ?
	echo Looking for input JSON at dummies/$inputs folder
	if [ ! -d dummies/$inputs ]; then echo ERROR: Folder does not exist!; exit; fi
	inputs="$( find dummies/$inputs -name "${inputs}.json" )"
	if [ -z $inputs ]; then echo ERROR: input JSON does not exist!; exit; fi 
fi
'
if [ ! -z $inputs ]; then
	inputs="${wdl%.wdl}.json"
fi
echo Looking for input JSON starting from the dummies folder
inputs="$( find $workflows -name "${inputs}" )"
if [ -z $inputs ]; then echo ERROR: input JSON does not exist!; exit; fi

set -x
java -Dconfig.file=${CROMWELL_CONFIG} -jar ${CROMWELL_PATH} run $wdl --inputs $inputs --options $WORKFLOW_OPTIONS