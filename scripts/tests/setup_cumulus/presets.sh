#!/bin/bash

set -euo pipefail

function default_preset {
	echo Setting up for check_inputs=true
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/fastq_dir.tsv"
	tool="Dropseq"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="mm10"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="dropseq_cumulus/testing/"
	check_inputs="--check_inputs"
}

function ds_is_bcl_preset {
	echo Setting up for check_inputs=true
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/bcl.tsv"
	tool="Dropseq"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="mm10"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="dropseq_cumulus/testing/"
	check_inputs="--check_inputs"
}

function ds_dge_preset {
	echo Setting up for check_inputs=true
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/IRA_dge.tsv"
	tool="Dropseq"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="mm10"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="dropseq_cumulus/testing/"
	check_inputs="--check_inputs"
}

function ss2_is_bcl_preset {
	echo Setting up for check_inputs=true
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_bcl_plate.tsv"
	tool="smartseq2"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="GRCm38_ens93filt"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="SS2/job/20200424/"
	check_inputs="--check_inputs"
}

function ss2_dge_preset {
	echo Setting up for check_inputs=true
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_dge.tsv"
	tool="smartseq2"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	reference="GRCm38_ens93filt"
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	output_directory_slash="SS2/job/20200424/"
	check_inputs="--check_inputs"
}