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
cd $scripts

# WDL COMMAND START
python scp_outputs.py \
	-i ${input_csv_file} \
	-s ${scp_outputs} \
	-m ${metadata_type_map}
# WDL COMMAND END

test_outputs="${scripts}/tests/scp_outputs/outputs/"
if [ -d ${test_outputs} ]; then rm -r ${test_outputs}; fi
mkdir -p ${test_outputs}
mv X_fitsne.coords.txt $test_outputs
mv expr.txt $test_outputs
mv metadata.txt $test_outputs
mv alexandria_metadata.txt $test_outputs
head ${test_outputs}/alexandria_metadata.txt