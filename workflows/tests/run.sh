#!/bin/bash
wdl="$1"
inputs="$2"
workflows="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows"

CROMWELL_PATH="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/cromwell-*.jar"
CROMWELL_CONFIG="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/cromwell.conf"
WORKFLOW_OPTIONS="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/cromwell_workflow_options.json"

set -euo pipefail

echo Looking for WDL script starting from the workflows folder
if [[ ! -d $workflows ]]; then echo ERROR: workflow folder does not exist!; exit; fi
wdl="$( find $workflows -name "${wdl}" -print -quit )"
if [[ -z $wdl ]]; then echo ERROR: WDL script does not exist!; exit; fi 

if [[ -z $inputs ]]; then
	inputs="${wdl%.wdl}.json"
	inputs="--inputs ${inputs}"
else
	if [[ "$inputs" == *".json" ]]; then
		inputs="$( find $workflows -name "${inputs}" -print -quit )"
		echo $inputs !
		if [[ -z $inputs ]]; then echo ERROR: input JSON does not exist!; exit; fi
		inputs="--inputs ${inputs}"
	else 
		echo WARNING: No .json suffix detected, running without input json!
		inputs=""
	fi

fi

set -x
cd cromwell
java -Dconfig.file=${CROMWELL_CONFIG} \
	-jar ${CROMWELL_PATH} \
	run $wdl \
	${inputs} \
	--options $WORKFLOW_OPTIONS
cd ..