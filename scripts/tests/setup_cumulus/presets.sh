#!/bin/bash

set -euo pipefail

function default_preset {
	echo Setting up for check_inputs=true
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/default_dir.csv"
	tool="dropseq"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="mm10"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="dropseq_cumulus/testing/"
	check_inputs="--check_inputs"
}

function ds_is_bcl_preset {
	echo Setting up for check_inputs=true
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/bcl.csv"
	tool="dropseq"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="mm10"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="dropseq_cumulus/testing/"
	check_inputs="--check_inputs"
}