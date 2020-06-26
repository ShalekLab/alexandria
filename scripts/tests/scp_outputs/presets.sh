#!/bin/bash

set -euo pipefail

function default_preset {
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/fastq_dir.tsv"
	tool="Dropseq"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/scp_outputs.txt"
}

function is_bcl_preset {
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/kbc_bcl.tsv"
	tool="Dropseq"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/bcl.txt"
}

function ss2_default {
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/alexandria_sheet_plates.tsv"
	tool="Smartseq2"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/ss2_scp_outputs.txt"
}

function cr_default {
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/BIOCRO_PILOT1.tsv"
	tool="Cellranger"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/cr_scp_outputs.txt"
}

function kb_bcl {
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/kbc_bcl.tsv"
	tool="Kallisto-Bustools"
	output_scp_files="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/scp_outputs/inputs/bcl.txt"
}