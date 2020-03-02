python /alexandria/scripts/setup_cumulus.py \
	-i=~{input_csv_file} \
	-t=dropseq \
	-g=~{bucket_slash} \
	~{true="--check_inputs" false='' check_inputs} \
	-r=~{reference} \
	-m=/alexandria/scripts/metadata_type_map.tsv \
	-o=~{dropseq_output_directory_slash}
gsutil cp count_matrix.csv ~{bucket_slash}~{cumulus_output_directory_slash}