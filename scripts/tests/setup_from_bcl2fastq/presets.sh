function ss2_default_preset {
	echo Setting up ss2 from bcl2fastq
	tool="Smartseq2"
	bcl2fastq_sheets="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_fastqs.txt"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/ss2_bcl_plate.tsv"
	#bucket_slash="gs://fc-secure-ec2ce7e8-339a-47b4-b9d9-34f652cbf41f/"
	#fastq_directory_slash=""
}

function kb_default {
	echo Setting up kb from bcl2fastq
	tool="Kallisto-Bustools"
	bcl2fastq_sheets="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/190806_NB501935_0657_AH3GYHBGX9_fastqs.txt /Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/190729_NB501935_0651_AHNHJFBGX9_fastqs.txt"
	alexandria_sheet="/Users/jggatter/Desktop/Alexandria/alexandria_repository/scripts/tests/common_inputs/kbc_bcl.tsv"
}