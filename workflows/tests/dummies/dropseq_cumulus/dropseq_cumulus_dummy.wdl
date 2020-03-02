version 1.0

workflow dropseq_cumulus {
	input {
		File input_csv_file

		String bucket

		String output_path
		
		String reference

		String? fastq_directory
		
		Boolean run_dropseq
		
		Boolean is_bcl #= false
		
		Boolean run_cumulus

		String dropseq_registry = "cumulusprod" # https://hub.docker.com/r/cumulusprod/dropseq/tags
		String dropseq_tools_version = "2.3.0"
		String bcl2fastq_registry = "gcr.io/broad-cumulus" # Privately hosted on Regev Lab GCR
		String bcl2fastq_version = "2.20.0.422"
		String cumulus_registry = "cumulusprod" # https://hub.docker.com/r/cumulusprod/cumulus/tags
		String cumulus_version = "0.14.0"
		String alexandria_docker = "shaleklab/alexandria:0.1" # https://hub.docker.com/repository/docker/shaleklab/alexandria/tags
		
		Int preemptible = 2
		
		String zones = "us-east1-d us-west1-a us-west1-b"

		String cumulus_output_prefix = "sco"
	}
	
	String bucket_slash = sub(bucket, "/+$", '')+'/'
	String output_path_slash = if output_path == '' then '' else sub(output_path, "/+$", '')+'/'
	
	String base_output_path_slash = sub(output_path_slash, bucket_slash, '')
	String dropseq_output_path_slash = base_output_path_slash+"dropseq/"
	String cumulus_output_path_slash = base_output_path_slash+"cumulus/"

	String dropseq_registry_stripped = sub(dropseq_registry, "/+$", '')
	String bcl2fastq_registry_stripped = sub(bcl2fastq_registry, "/+$", '')
	String cumulus_registry_stripped = sub(cumulus_registry, "/+$", '')

	Boolean check_inputs = !run_dropseq

	if (run_dropseq) {
		call setup_dropseq { # Check user inputs .csv and create dropseq_locations.tsv for dropseq and/or count_matrix.csv for cumulus
			input:
				bucket_slash=bucket_slash,
				is_bcl=is_bcl,
				input_csv_file=input_csv_file,
				reference=reference,
				dropseq_output_directory_slash=dropseq_output_directory_slash,
				fastq_directory_slash=fastq_directory_slash,
				alexandria_docker=alexandria_docker,
				preemptible=preemptible,
				zones=zones
		}
		call dropseq.dropseq_workflow as dropseq {
			input:
				input_tsv_file=setup_dropseq.dropseq_locations,
				run_bcl2fastq=is_bcl,
				output_directory=bucket_slash + sub(dropseq_output_directory_slash, "/+$", ''),
				reference=reference,
				docker_registry=dropseq_registry_stripped,
				drop_seq_tools_version=dropseq_tools_version,
				bcl2fastq_registry=bcl2fastq_registry_stripped,
				bcl2fastq_version=bcl2fastq_version,
				zones=zones,
				preemptible=preemptible
		}
	}

	if (run_cumulus) {
		call setup_cumulus{
			input: 
				check_inputs=check_inputs,
				input_csv_file=input_csv_file,
				reference=reference,
				bucket_slash=bucket_slash,
				dropseq_output_directory_slash=dropseq_output_directory_slash,
				cumulus_output_directory_slash=cumulus_output_directory_slash,
				alexandria_docker=alexandria_docker,
				preemptible=preemptible,
				zones=zones
		}
		call cumulus.cumulus as cumulus {
			input:
				input_file=setup_cumulus.count_matrix,
				output_name=bucket_slash + cumulus_output_directory_slash + cumulus_output_prefix,
				is_dropseq=true,
				generate_scp_outputs=true,
				output_dense=true,
				preemptible=preemptible,
				zones=zones,
				docker_registry=cumulus_registry_stripped,
				cumulus_version=cumulus_version
		}
		call scp_outputs {
			input:
				input_csv_file=input_csv_file,
				preemptible=preemptible,
				bucket_slash=bucket_slash,
				cumulus_output_directory_slash=cumulus_output_directory_slash,
				cumulus_output_prefix=cumulus_output_prefix, 
				output_scp_files=cumulus.output_scp_files,
				alexandria_docker=alexandria_docker
		}
	}
}

task setup_dropseq {
	input {
		String bucket_slash
		Boolean is_bcl
		File input_csv_file
		String reference
		String dropseq_output_directory_slash
		String? fastq_directory_slash
		String alexandria_docker
		Int preemptible
		String zones
	}
	command <<<
		echo dropseq_locations.tsv >> dropseq_locations.tsv
	>>>
	output {
		File dropseq_locations = "dropseq_locations.tsv"
	}
	runtime {
		docker: "~{alexandria_docker}"
		preemptible: "~{preemptible}"
		zones: "~{zones}"
	}
}

task setup_cumulus {
	input {
		Boolean check_inputs
		File input_csv_file
		String reference
		String bucket_slash
		String dropseq_output_directory_slash
		String cumulus_output_directory_slash
		String alexandria_docker
		Int preemptible
		String zones
	}
	command <<<
		echo count_matrix.csv >> count_matrix.csv
	>>>
	output {
		File count_matrix = "count_matrix.csv"
	}
	runtime {
		docker: "~{alexandria_docker}"
		preemptible: "~{preemptible}"
		zones: "~{zones}"
	}
}

task scp_outputs {
	input {
		File input_csv_file
		String cumulus_output_directory_slash
		Array[String] output_scp_files
		String bucket_slash
		String alexandria_docker
		Int preemptible
		String zones
	}
	command <<<
		echo alexandria_metadata.txt >> alexandria_metadata.txt
	>>>
	output {
		File alexandria_metadata = "alexandria_metadata.txt"
	}
	runtime {
		docker: "~{alexandria_docker}"
		preemptible: "~{preemptible}"
		zones: "~{zones}"
	}
}