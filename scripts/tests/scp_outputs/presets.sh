#!/bin/bash

set -euo pipefail

function default_preset {
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/default_dir.csv"
	tool="dropseq"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/scp_outputs.txt"
}

function default_preset {
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/bcl.csv"
	tool="dropseq"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/???"
}