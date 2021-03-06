#!/bin/bash

if [ ! -e presets.sh ]; then 
	echo "ALEXANDRIA DEV: ERROR! presets.sh library script not found."
	exit
fi
source presets.sh

if [ $# -eq 0 ]; then 
	ds_default_preset
else 
	$1
fi

set -euo pipefail

scripts="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts"
cd $scripts

# WDL COMMAND START
python setup_tool.py \
	-t=${tool} \
	-i=${alexandria_sheet} \
	-g=${bucket_slash} \
	${is_bcl} \
	-f=${fastq_directory_slash} \
	-r=${reference} \
	${aligner}
# WDL COMMAND END

# Verify outputs
if [ -e trimmed_sample_sheet.csv ]; then rm trimmed_sample_sheet.csv; fi

test_outputs="${scripts}/tests/setup_tool/outputs/"
if [ -d ${test_outputs} ]; then rm -r ${test_outputs}; fi
mkdir -p ${test_outputs}
mv ${tool}_locations.tsv $test_outputs
head ${test_outputs}${tool}_locations.tsv