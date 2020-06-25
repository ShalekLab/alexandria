#!/bin/bash

if [ ! -e presets.sh ]; then 
	echo "ALEXANDRIA DEV: ERROR! presets.sh library script not found."
	exit
fi
source presets.sh

if [ $# -eq 0 ]; then 
	ss2_default_preset
else 
	$1
fi

set -euo pipefail

scripts="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts"
cd $scripts

# WDL COMMAND START
python setup_from_bcl2fastq.py \
	-t=${tool} \
	-b ${bcl2fastq_sheets} \
	-i=${alexandria_sheet}
# WDL COMMAND END

# Verify outputs
test_outputs="${scripts}/tests/setup_from_bcl2fastq/outputs/"
if [ -d ${test_outputs} ]; then rm -r ${test_outputs}; fi
mkdir -p ${test_outputs}
mv ${tool}_locations.tsv $test_outputs
head ${test_outputs}${tool}_locations.tsv