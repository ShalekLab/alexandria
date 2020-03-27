workflow dropseq_cumulus {
	Array[File] output_scp_files = ["gs://shalek-lab-cromwell/dropseq_cumulus/cumulus/sco.scp.X_fitsne.coords.txt", "gs://shalek-lab-cromwell/dropseq_cumulus/cumulus/sco.scp.expr.txt", "gs://shalek-lab-cromwell/dropseq_cumulus/cumulus/sco.scp.metadata.txt"]
	File input_csv_file = "gs://shalek-lab-cromwell/dropseq_cumulus/IRAs_remake_this_for_next_job.csv"
	String bucket_slash = "gs://shalek-lab-cromwell/"
	String cumulus_output_path_slash = "dropseq_cumulus/jobs/dcd/"

	call scp_outputs {
		input:
			output_scp_files=output_scp_files,
			input_csv_file=input_csv_file,
			bucket_slash=bucket_slash,
			cumulus_output_path_slash=cumulus_output_path_slash
	}
	output {
		String? cumulus_output_path = cumulus_output_path_slash
        File? alexandria_metadata = scp_outputs.alexandria_metadata
		File? fitsne_coords = scp_outputs.fitsne_coords
		File? dense_matrix = scp_outputs.dense_matrix
		File? cumulus_metadata = scp_outputs.cumulus_metadata
	}
}

task scp_outputs {
	Array[File] output_scp_files
	File input_csv_file
	String bucket_slash
	String cumulus_output_path_slash

	command {
		set -e
		printf "${sep='\n' output_scp_files}" >> output_scp_files.txt
		echo PWD && pwd
		echo LS && ls -1
		echo CAT && cat output_scp_files.txt

		python /alexandria/scripts/scp_outputs.py \
			-i ${input_csv_file} \
			-t dropseq \
			-s output_scp_files.txt \
			-m /alexandria/scripts/metadata_type_map.tsv
		gsutil cp alexandria_metadata.txt ${bucket_slash}${cumulus_output_path_slash}
		
		cat metadata.txt
		cat X_fitsne.coords.txt
		cat expr.txt
	}
	output {
		File alexandria_metadata = "alexandria_metadata.txt"
		File cumulus_metadata = read_string("metadata.txt")
		File fitsne_coords = read_string("X_fitsne.coords.txt")
		File dense_matrix = read_string("expr.txt")
	}
	runtime {
		docker: "shaleklab/alexandria:dev"
	}
}