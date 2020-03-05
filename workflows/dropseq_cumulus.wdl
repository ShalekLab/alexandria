# dropseq_cumulus workflow
# A publicly available WDL workflow made by Shalek Lab for bridging dropseq_workflow and cumulus workflow
# By jgatter [at] broadinstitute.org, created December 16th, 2019
# Incorporates subworkflows made by jgould [at] broadinstitute.org of the Cumulus Team
# Drop-Seq Tools Pipeline by McCarroll Lab (https://github.com/broadinstitute/Drop-seq/blob/master/doc/Drop-seq_Alignment_Cookbook.pdf)
# Cumulus by the Cumulus Team (https://cumulus-doc.readthedocs.io/en/latest/index.html)
# ------------------------------------------------------------------------------------------------------------------------------------------
# VERSION 1
# Release
# ------------------------------------------------------------------------------------------------------------------------------------------

import "https://api.firecloud.org/ga4gh/v1/tools/cumulus:dropseq_workflow/versions/7/plain-WDL/descriptor" as dropseq
import "https://api.firecloud.org/ga4gh/v1/tools/cumulus:cumulus/versions/16/plain-WDL/descriptor" as cumulus

workflow dropseq_cumulus {
	# User-inputted .csv file that contains in whatever order:
	#	(REQUIRED) the 'Sample' column, 
	#	(OPTIONAL) both 'R1_Path' and 'R2_Path' columns
	#	(OPTIONAL) 'BCL_Path' column
	#	(OPTIONAL) 'SS_Path' column
	#	(OPTIONAL) other metadata columns that currently aren't used/outputted by the workflow
	File input_csv_file

	# The gsURI of your Google Bucket, ex: "gs://your-bucket-id/FASTQs/"
	# Alexandria/The Single Cell Portal requires this variable.
	String bucket

	# The gsURI path following the bucket root to the folder where you wish the pipeline to deposit files
	# ex: "dropseq_cumulus/my-job/" from gs://your-bucket-id/dropseq_cumulus/my-job/
	# Inside this folder (ex: my-job/) folders for each tool will be created ("dropseq/" and "cumulus/")
	String output_path
	
	# Accepted references are "hg19", "mm10", "hg19_mm10", "mmul_8.0.1", and "GRCh38"
	# For making and linking custom dropseq-compatible references, see the Cumulus documentation.
	String reference

	# If you have some/all of your FASTQs in one folder object on the bucket,
	# enter the gsURI path to that folder object following the bucket root.
	# ex: "FASTQs/" from full gsURI gs://your-bucket-id/FASTQs/
	String? fastq_directory
	
	# Set true to run alignment by Drop-Seq tools
	Boolean run_dropseq
	
	# Set to true to convert your BCLs to FASTQs via bcl2fastq
	Boolean is_bcl #= false
	
	# Set to true to produce clustering/visualization data via Cumulus
	# Alexandria/The Single Cell Portal require these data files.
	Boolean run_cumulus

	### Docker image information. Addresses are formatted as <registry name>/<image name>:<version tag>
	# dropseq_workflow docker image
	String dropseq_registry = "cumulusprod" # https://hub.docker.com/r/cumulusprod/dropseq/tags
	String dropseq_tools_version = "2.3.0"
	# bcl2fastq docker image
	# To use bcl2fastq you MUST locally `docker login` to your broadinstitute.org-affiliated docker account.
	# If not Broad-affiliated, see the Alexandria documentation appendix for creating your own bcl2fastq image.
	String bcl2fastq_registry = "gcr.io/broad-cumulus" # Privately hosted on Regev Lab GCR
	String bcl2fastq_version = "2.20.0.422"
	# cumulus workflow docker image
	String cumulus_registry = "cumulusprod" # https://hub.docker.com/r/cumulusprod/cumulus/tags
	String cumulus_version = "0.14.0"
	# alexandria docker image
	String alexandria_docker = "shaleklab/alexandria:0.2" # https://hub.docker.com/repository/docker/shaleklab/alexandria/tags
	
	# The maximum number of attempts Cromwell will request Google for a preemptible VM.
	# Preemptible VMs are about 5 times cheaper than non-preemptible, but Google can yank them
	# out from under you at anytime. If in a rush, set it to 0.
	Int preemptible = 2
	
	# The priority queue for requesting a Google Cloud Platform zone.
	# Change the default value to reflect where your bucket is located.
	String zones = "us-east1-d us-west1-a us-west1-b"

	#The filename prefix assigned to the Cumulus outputs.
	String cumulus_output_prefix = "sco"
	
	### MANIPULATIONS: PLEASE IGNORE ###
	String bucket_slash = sub(bucket, "/+$", '')+'/'
	String output_path_slash = if output_path == '' then '' else sub(output_path, "/+$", '')+'/'
	String fastq_directory_slash = if fastq_directory == '' then '' else sub(fastq_directory, "/+$", '')+'/'

	String base_fastq_directory_slash = sub(fastq_directory_slash, bucket_slash, '')
	String base_output_path_slash = sub(output_path_slash, bucket_slash, '')
	String dropseq_output_path_slash = base_output_path_slash+"dropseq/"
	String cumulus_output_path_slash = base_output_path_slash+"cumulus/"

	String dropseq_registry_stripped = sub(dropseq_registry, "/+$", '')
	String bcl2fastq_registry_stripped = sub(bcl2fastq_registry, "/+$", '')
	String cumulus_registry_stripped = sub(cumulus_registry, "/+$", '')

	Boolean check_inputs = !run_dropseq

	if (run_dropseq) {
		# Check user input_csv_file and create dropseq_locations.tsv for Drop-Seq Tools
		call setup_dropseq {
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
		# Check user input_csv_file if check_inputs==true and create count_matrix.csv for Cumulus
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
		# Segregate the output scp files and map the input_csv_file's metadata to create the alexandria_metadata.txt
		call scp_outputs {
			input:
				input_csv_file=input_csv_file,
				bucket_slash=bucket_slash,
				cumulus_output_directory_slash=cumulus_output_directory_slash,
				cumulus_output_prefix=cumulus_output_prefix, 
				output_scp_files=cumulus.output_scp_files,
				alexandria_docker=alexandria_docker,
				preemptible=preemptible,
				zones=zones
		}
	}
	output {
		File alexandria_metadata = scp_outputs.alexandria_metadata
		#File pca_coords = scp_outputs.pca_coords
		File fitsne_coords = scp_outputs.fitsne_coords
		File dense_matrix = scp_outputs.dense_matrix
		File cumulus_metadata = scp_outputs.cumulus_metadata
	}
}

task setup_dropseq {
	
	String bucket_slash
	Boolean is_bcl
	File input_csv_file
	String reference
	String dropseq_output_directory_slash
	String? fastq_directory_slash
	String alexandria_docker
	Int preemptible
	String zones
	
	command {
		set -e
		python /alexandria/scripts/setup_tool.py \
			-t=dropseq \
			-i=${input_csv_file} \
			-g=${bucket_slash} \
			${true="--is_bcl" false='' is_bcl} \
			-m=/alexandria/scripts/metadata_type_map.tsv \
			-f=${fastq_directory_slash} \
			-r=${reference}
		gsutil cp dropseq_locations.tsv ${bucket_slash}${dropseq_output_directory_slash}
	}
	output {
		File dropseq_locations = "dropseq_locations.tsv"
	}
	runtime {
		docker: "${alexandria_docker}"
		preemptible: "${preemptible}"
		zones: "${zones}"
	}
}

task setup_cumulus {
	
	Boolean check_inputs
	File input_csv_file
	String reference
	String bucket_slash
	String dropseq_output_directory_slash
	String cumulus_output_directory_slash
	String alexandria_docker
	Int preemptible
	String zones
	
	command {
		set -e
		python /alexandria/scripts/setup_cumulus.py \
			-i=${input_csv_file} \
			-t=dropseq \
			-g=${bucket_slash} \
			${true="--check_inputs" false='' check_inputs} \
			-r=${reference} \
			-m=/alexandria/scripts/metadata_type_map.tsv \
			-o=${dropseq_output_directory_slash}
		gsutil cp count_matrix.csv ${bucket_slash}${cumulus_output_directory_slash}
	}
	output {
		File count_matrix = "count_matrix.csv"
	}
	runtime {
		docker: "${alexandria_docker}"
		preemptible: "${preemptible}"
		zones: "${zones}"
	}
}

task scp_outputs {
	
	File input_csv_file
	String cumulus_output_directory_slash
	Array[String] output_scp_files
	String bucket_slash
	String alexandria_docker
	Int preemptible
	String zones
	
	command {
		set -e
		python /alexandria/scripts/scp_outputs.py \
			-i ${input_csv_file} \
			-s ${write_lines(output_scp_files)} \
			-m /alexandria/scripts/metadata_type_map.tsv
		gsutil cp alexandria_metadata.txt ${bucket_slash}${cumulus_output_directory_slash}
	}
	output {
		File alexandria_metadata = "alexandria_metadata.txt"
		#File? pca_coords = read_string(select_first(glob("*X_diffmap_pca.coords.txt")))
		File cumulus_metadata = read_string("metadata.txt")
		File fitsne_coords = read_string(glob("*X_fitsne\.coords\.txt")[0])
		File dense_matrix = read_string(glob("*expr\.txt")[0])
	}
	runtime {
		docker: "${alexandria_docker}"
		preemptible: "${preemptible}"
		zones: "${zones}"
	}
}
