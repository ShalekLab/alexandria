python /alexandria/scripts/scp_outputs.py \
	-i ~{input_csv_file} \
	-s ~{output_scp_files} \
	-m /alexandria/scripts/metadata_type_map.tsv
gsutil cp alexandria_metadata.txt ~{bucket_slash}~{cumulus_output_directory_slash}