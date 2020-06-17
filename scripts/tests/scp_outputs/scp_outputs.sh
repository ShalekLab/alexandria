#!/bin/bash
set -euo pipefail

if [ ! -e presets.sh ]; then 
	echo "ALEXANDRIA DEV: ERROR! presets.sh library script not found."
	exit
fi
source presets.sh

if [ $# -eq 0 ]; then 
	default_preset
else 
	$1
fi

scripts="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts"
scp_outputs="${scripts}/tests/scp_outputs"

cd $scripts
cp ${scp_outputs}/inputs_copy/* ${scp_outputs}/inputs/

# WDL COMMAND START
set +e
echo Running
python scp_outputs.py \
	-i ${alexandria_sheet} \
	-t ${tool} \
	-s ${output_scp_files}
# WDL COMMAND END

test_outputs="${scp_outputs}/outputs"
if [ -d ${test_outputs} ]; then trash ${test_outputs}; fi
mkdir -p ${test_outputs}
mv *scp.X_*.coords.txt $test_outputs
mv *scp.expr.txt $test_outputs
mv *scp.metadata.txt $test_outputs
mv alexandria_metadata.txt $test_outputs
head ${test_outputs}/alexandria_metadata.txt