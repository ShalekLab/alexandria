#!/bin/bash

set -euo pipefail

function default_preset {
	echo Setting up for is_bcl=false and fastq_directory=""
	tool="dropseq"
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/default_dir.csv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function fastq_directory_preset {
	echo Setting up for is_bcl=false and fastq_directory="dropseq_cumulus/IRA_FASTQs/"
	tool="dropseq"
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/default_dir.csv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash="dropseq_cumulus/IRA_FASTQs/"
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function is_bcl_preset {
	echo Setting up for is_bcl=true
	tool="dropseq"
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/bcl.csv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="--is_bcl" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function ss2_default_preset {
	echo Setting up for is_bcl=false and fastq_directory=""
	tool="smartseq2"
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_short.csv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function ss2_fastq_directory_preset {
	echo Setting up for is_bcl=false and fastq_directory="dropseq_cumulus/IRA_FASTQs/"
	tool="smartseq2"
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/???"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash="dropseq_cumulus/IRA_FASTQs/"
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function ss2_is_bcl_preset {
	echo Setting up for is_bcl=true
	tool="smartseq2"
	input_csv_file="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/???"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="--is_bcl" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}