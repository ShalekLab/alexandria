#!/bin/bash

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

set -euo pipefail

src="/Users/jggatter/Desktop/Alexandria/alexandria_repository/src"
cd $src

# WDL COMMAND START
python setup_dropseq.py \
	-i=${input_csv_file} \
	-g=${bucket_slash} \
	${is_bcl} \
	-m=${metadata_type_map} \
	-f=${fastq_directory_slash} \
	-r=${reference}
# WDL COMMAND END

# Verify outputs
if [ -e trimmed_sample_sheet.csv ]; then rm trimmed_sample_sheet.csv; fi

test_outputs="${src}/tests/setup_dropseq/outputs/"
if [ -d ${test_outputs} ]; then rm -r ${test_outputs}; fi
mkdir -p ${test_outputs}
mv dropseq_locations.tsv $test_outputs
head ${test_outputs}dropseq_locations.tsv