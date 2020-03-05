#!/bin/bash
set -euo pipefail

wdl="$1"
workflows="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows"
WOMTOOL_PATH="/Users/jggatter/Desktop/Alexandria/alexandria_repository/workflows/tests/cromwell/womtool-*.jar"

echo Looking for WDL script starting from the workflows folder
if [ ! -d $workflows ]; then echo ERROR: Workflows folder does not exist!; exit; fi
wdl="$( find $workflows -name "$wdl" )"
if [ -z $wdl ]; then echo ERROR: WDL script does not exist!; exit; fi 

inputs="${wdl%.wdl}.json"
set -x
java -jar $WOMTOOL_PATH inputs $wdl > $inputs
set +x

cat $inputs

output_dir="${workflows}/tests/dummies/$( basename -s _dummy.wdl $wdl )/"
echo Moving inputs to $output_dir
mkdir -p $output_dir
mv $inputs $output_dir