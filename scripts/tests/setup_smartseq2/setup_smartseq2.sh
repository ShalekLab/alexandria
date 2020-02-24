#!/bin/bash
set -euo pipefail

if [ ! -e presets.sh ]; then 
	echo "ALEXANDRIA DEV: ERROR! presets.sh library script not found."
	exit
fi
source presets.sh

if [ $# -eq 0 ];then 
	default_preset
else 
	$1
fi

source presets.sh
scripts="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts"
cd $scripts

# WDL COMMAND START
python setup_smartseq2.py \
	-i=${input_csv_file} \
	-g=${bucket_slash} \
	${is_bcl} \
	-m=${metadata_type_map} \
	-f=${fastq_directory_slash} \
	-r=${reference}
# WDL COMMAND END

# Verify outputs
if [ -e trimmed_sample_sheet.csv ]; then rm trimmed_sample_sheet.csv; fi

test_outputs="${scripts}/tests/setup_smartseq2/outputs/"
if [ -d ${test_outputs} ]; then rm -r ${test_outputs}; fi
mkdir -p ${test_outputs}
mv smartseq2_locations.tsv $test_outputs
head ${test_outputs}smartseq2_locations.tsv