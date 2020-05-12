#!/bin/bash

set -euo pipefail

function ds_default_preset {
	echo Setting up ds for is_bcl=false and fastq_directory=""
	tool="Dropseq"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/IRA.tsv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function ds_fastq_directory_preset {
	echo Setting up ds for is_bcl=false and fastq_directory="dropseq_cumulus/IRA_FASTQs/"
	tool="Dropseq"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/fastq_dir.tsv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash="dropseq_cumulus/IRA_FASTQs/"
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function ds_is_bcl_preset {
	echo Setting up ds for is_bcl=true
	tool="Dropseq"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ds_bcl.tsv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="--is_bcl" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function ds_fq_gsURIs {
	echo Setting up ds for FQs with gsURIs
	tool="Dropseq"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/dropseq_gsURIs.tsv"
	bucket_slash="gs://shalek-lab-archiving/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function ds_bcl_gsURIs {
	echo Setting up ds for sequencing directories with gsURIs
	tool="Dropseq"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/bcl_gsURIs.tsv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="--is_bcl" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}


function ss2_default_preset {
	echo Setting up ss2 for is_bcl=false and fastq_directory=""
	tool="Smartseq2"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_short.tsv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="GRCm38_ens93filt"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
	aligner="-a=star"
}
: '
function ss2_fastq_directory_preset {
	echo Setting up ss2 for is_bcl=false and fastq_directory="dropseq_cumulus/IRA_FASTQs/"
	tool="Smartseq2"
	#alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/???"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash="dropseq_cumulus/IRA_FASTQs/"
	reference="GRCh38_ens93filt"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
	aligner="star"
}
'
function ss2_is_bcl_preset {
	echo Setting up ss2 for is_bcl=true
	tool="Smartseq2"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_bcl.tsv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="--is_bcl" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="GRCm38_ens93filt"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
	aligner="-a=hisat2-hca"
}
: '
function kb_default_preset {
	echo Setting up kb for is_bcl=false and fastq_directory=""
	tool="Kallisto_Bustools"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_short.tsv"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function kb_fastq_directory_preset {
	echo Setting up kb for is_bcl=false and fastq_directory="dropseq_cumulus/IRA_FASTQs/"
	tool="Kallisto_Bustools"
	#alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/???"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash="dropseq_cumulus/IRA_FASTQs/"
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}

function kb_is_bcl_preset {
	echo Setting up kb for is_bcl=true
	tool="Kallisto_Bustools"
	#alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/???"
	bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	is_bcl="--is_bcl" # isbcl=${true="--is_bcl" false="" is_bcl}
	metadata_type_map="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/metadata_type_map.tsv"
	fastq_directory_slash=""
	reference="mm10"
	output_directory_slash="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/setup_tool/outputs/"
}
'