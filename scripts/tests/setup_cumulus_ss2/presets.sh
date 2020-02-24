#!/bin/bash

set -euo pipefail

function default_preset {
	echo Setting up for run_dropseq=true
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_normal.csv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="mm10"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="smartseq2/testing/"
	run_dropseq="--run_dropseq"
}