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
python setup_cumulus.py \
	-i=${alexandria_sheet} \
	-t=${tool} \
	-g=${bucket_slash} \
	${check_inputs} \
	-r=${reference} \
	-m=${metadata_type_map} \
	-o=${output_directory_slash}
# WDL COMMAND END

test_outputs="${scripts}/tests/setup_cumulus/outputs/"
if [ -d ${test_outputs} ]; then rm -r ${test_outputs}; fi
mkdir -p ${test_outputs}
mv count_matrix.csv $test_outputs
head ${test_outputs}/count_matrix.csv