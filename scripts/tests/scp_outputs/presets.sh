#!/bin/bash

set -euo pipefail

function default_preset {
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/fastq_dir.tsv"
	tool="Dropseq"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/scp_outputs.txt"
}

function is_bcl_preset {
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/bcl.tsv"
	tool="Dropseq"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/???"
}