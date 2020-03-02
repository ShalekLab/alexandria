python /alexandria/scripts/setup_tool.py \
	-t=dropseq \
	-i=~{input_csv_file} \
	-g=~{bucket_slash} \
	~{true="--is_bcl" false='' is_bcl} \
	-m=/alexandria/scripts/metadata_type_map.tsv \
	-f=~{fastq_directory_slash} \
	-r=~{reference}
gsutil cp dropseq_locations.tsv ~{bucket_slash}~{dropseq_output_directory_slash}