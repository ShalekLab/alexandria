# kallisto_bustools_cumulus workflow
# A publicly available WDL workflow made by Shalek Lab for bridging kallisto_bustools and cumulus workflow
# By jgatter [at] broadinstitute.org, published ~!!INSERT HERE!!~
# Incorporates subworkflows made by the Cumulus Team
# Cumulus by the Cumulus Team (https://cumulus-doc.readthedocs.io/en/latest/index.html)
# ------------------------------------------------------------------------------------------------------------------------------------------
# SNAPSHOT 1
# Release
# ------------------------------------------------------------------------------------------------------------------------------------------

version 1.0
import "https://api.firecloud.org/ga4gh/v1/tools/alexandria:kallisto-bustools/versions/3/plain-WDL/descriptor" as kallisto_bustools
import "https://api.firecloud.org/ga4gh/v1/tools/cumulus:cumulus/versions/24/plain-WDL/descriptor" as cumulus
import "https://api.firecloud.org/ga4gh/v1/tools/cumulus:bcl2fastq/versions/5/plain-WDL/descriptor" as bcl2fastq

workflow kallisto_bustools_cumulus {
	input {
		# User-inputted .tsv file that contains in whatever order:
		#	(REQUIRED) the 'Sample' column, 
		#	(REQUIRED is_bcl==false) both 'R1_Paths' and 'R2_Paths' columns
		#	(REQUIRED is_bcl==true) 'BCL_Path' column
		#	(OPTIONAL) 'SS_Path' column
		#	(OPTIONAL) Metadata columns for upload to SCP
		File alexandria_sheet

		# The gsURI of your Google Bucket, ex: "gs://your-bucket-id/FASTQs/"
		# Alexandria/The Single Cell Portal requires this variable.
		String bucket

		# The gsURI path following the bucket root to the folder where you wish the pipeline to deposit files
		# ex: "kallisto_bustools_cumulus/my-job/" from gs://your-bucket-id/kallisto_bustools_cumulus/my-job/
		# Inside this folder (ex: my-job/) folders for each tool will be created ("kallisto_bustools/" and "cumulus/")
		String output_path

		String? download_kb_index
		
		# Set true to run pseudoalignment by Kallisto-Bustools tools
		Boolean run_kallisto_bustools
		Boolean run_build_reference
		String technology
		Boolean use_lamanno
		Boolean delete_bus_files

		# Set to true to convert your BCLs to FASTQs via bcl2fastq
		Boolean is_bcl #= false
		
		# Set to true to produce clustering/visualization data via Cumulus
		# Alexandria/The Single Cell Portal require these data files.
		Boolean run_cumulus
		# Accepted options: (mm9, mm10, GRCh38, hg19)
		String cumulus_reference

		# The filename prefix assigned to the Cumulus outputs.
		String cumulus_output_prefix = "kbc"

		# Recommended Cumulus parameters values for Kallisto-Bustools data:
		#Int cumulus_tsne_perplexity = 10
		#Int cumulus_nPC = 15 # Number of Principal Components
		#Int cumulus_knn_K = 10 # Number of nearest neighbors per node
		#Int cumulus_max_genes = 15000
		#Int cumulus_max_umis = 3000000

		### Docker image information. Addresses are formatted as <registry name>/<image name>:<version tag>
		# kallisto_bustools docker image: <registry>/kallisto_bustools:<tag version>
		String kallisto_bustools_docker = "shaleklab/kallisto-bustools:0.24.4" # https://hub.docker.com/r/shaleklab/kallisto-bustools/tags
		# bcl2fastq docker image: <bcl2fastq_registry>/bcl2fastq:<bcl2fastq_version>
		# To use bcl2fastq you MUST locally `docker login` to your broadinstitute.org-affiliated docker account.
		# If not Broad-affiliated, see the Alexandria documentation appendix for creating your own bcl2fastq image.
		String bcl2fastq_registry = "gcr.io/broad-cumulus" # Privately hosted on Regev Lab GCR
		String bcl2fastq_version = "2.20.0.422"
		# cumulus workflow docker image: <cumulus_registry>/cumulus:<cumulus_version>
		String cumulus_registry = "cumulusprod" # https://hub.docker.com/r/cumulusprod/cumulus/tags
		String cumulus_version = "0.16.0"
		# alexandria docker image: <alexandria_docker>
		String alexandria_docker = "shaleklab/alexandria:0.3" # https://hub.docker.com/repository/docker/shaleklab/alexandria/tags
		
		# The maximum number of attempts Cromwell will request Google for a preemptible VM.
		# Preemptible VMs are about 5 times cheaper than non-preemptible, but Google can yank them
		# out from under you at anytime. If in a rush, set it to 0 but remember costs will be higher!
		Int preemptible = 2
		
		# The priority queue for requesting a Google Cloud Platform zone.
		# Change the default value to reflect where your bucket is located.
		String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
	}
	String bucket_slash = sub(bucket, "/+$", '')+'/'
	String output_path_slash = if output_path == '' then '' else sub(output_path, "/+$", '')+'/' 

	String base_output_path_slash = sub(output_path_slash, bucket_slash, '')
	String kallisto_bustools_output_path_slash = base_output_path_slash+"kallisto-bustools/"
	String cumulus_output_path_slash = base_output_path_slash+"cumulus/"

	String bcl2fastq_registry_stripped = sub(bcl2fastq_registry, "/+$", '')
	String cumulus_registry_stripped = sub(cumulus_registry, "/+$", '')

	Boolean check_inputs = !run_kallisto_bustools

	if (run_kallisto_bustools) {
		# Check user alexandria_sheet and create kallisto_bustools_locations.tsv for kb
		call setup_kallisto_bustools as setup_kb {
			input:
				bucket_slash=bucket_slash,
				is_bcl=is_bcl,
				alexandria_sheet=alexandria_sheet,
				reference=cumulus_reference,
				kallisto_bustools_output_path_slash=kallisto_bustools_output_path_slash,
				alexandria_docker=alexandria_docker,
				preemptible=preemptible,
				zones=zones
		}
		if (is_bcl) {
			scatter (entry in read_tsv(setup_kb.kallisto_bustools_locations)) {
				call bcl2fastq.bcl2fastq {
					input:
						input_bcl_directory=entry[0],
						sample_sheet=entry[1],
						output_directory = bucket_slash + sub(kallisto_bustools_output_path_slash, "/+$", ''),
						zones=zones,
						preemptible=preemptible,
						bcl2fastq_version=bcl2fastq_version,
						docker_registry=bcl2fastq_registry_stripped
				}
			}
			call setup_from_bcl2fastq {
				input:
					bucket_slash=bucket_slash,
					alexandria_sheet=alexandria_sheet,
					bcl2fastq_sheets=bcl2fastq.fastqs,
					alexandria_docker=alexandria_docker,
					zones=zones,
					preemptible=preemptible
			}
		}
		call kallisto_bustools.kallisto_bustools as kb {
			input:
				bucket=bucket_slash,
				output_path=kallisto_bustools_output_path_slash,
				sample_sheet=select_first([setup_from_bcl2fastq.kallisto_bustools_locations, setup_kb.kallisto_bustools_locations]),
				download_index=download_kb_index,
				run_build_reference=run_build_reference,
				technology=technology,
				use_lamanno=use_lamanno,
				delete_bus_files=delete_bus_files,
				docker=kallisto_bustools_docker,
				zones=zones,
				preemptible=preemptible
		}
	}
	if (run_cumulus) {
		# Check user alexandria_sheet if check_inputs==true and create count_matrix.csv for Cumulus
		call setup_cumulus {
			input: 
				check_inputs=check_inputs,
				alexandria_sheet=alexandria_sheet,
				reference=cumulus_reference,
				bucket_slash=bucket_slash,
				kallisto_bustools_output_path_slash=kallisto_bustools_output_path_slash,
				cumulus_output_path_slash=cumulus_output_path_slash,
				count_output_paths=kb.count_output_paths,
				alexandria_docker=alexandria_docker,
				preemptible=preemptible,
				zones=zones
		}
		call cumulus.cumulus as cumulus {
			input:
				input_file=setup_cumulus.count_matrix,
				output_directory=bucket_slash + cumulus_output_path_slash,
				output_name=cumulus_output_prefix,
				is_dropseq=false,
				generate_scp_outputs=true,
				output_dense=true,
				preemptible=preemptible,
				zones=zones,
				docker_registry=cumulus_registry_stripped,
				cumulus_version=cumulus_version
		}
		# Segregate the output scp files and map the alexandria_sheet's metadata to create the alexandria_metadata.txt
		call scp_outputs {
			input:
				alexandria_sheet=alexandria_sheet,
				bucket_slash=bucket_slash,
				cumulus_output_path_slash=cumulus_output_path_slash, 
				output_scp_files=cumulus.output_scp_files,
				alexandria_docker=alexandria_docker,
				preemptible=preemptible,
				zones=zones
		}
	}
	output {
		String? kallisto_bustools_output_path = bucket_slash + kallisto_bustools_output_path_slash
		String? cumulus_output_path = bucket_slash + cumulus_output_path_slash
		
		File? alexandria_metadata = scp_outputs.alexandria_metadata
		File? fitsne_coords = scp_outputs.fitsne_coords
		File? dense_matrix = scp_outputs.dense_matrix
		File? cumulus_metadata = scp_outputs.cumulus_metadata
		File? pca_coords = scp_outputs.pca_coords
	}
}

task setup_kallisto_bustools {
	input {
		String bucket_slash
		Boolean is_bcl
		File alexandria_sheet
		String reference
		String kallisto_bustools_output_path_slash
		String alexandria_docker
		Int preemptible
		String zones
	}
	command <<<
		set -e
		python /alexandria/scripts/setup_tool.py \
			-t=Kallisto-Bustools \
			-i=~{alexandria_sheet} \
			-g=~{bucket_slash} \
			~{true="--is_bcl" false='' is_bcl} \
			-r=~{reference}
		gsutil cp kallisto-bustools_locations.tsv ~{bucket_slash}~{kallisto_bustools_output_path_slash}
	>>>
	output {
		File kallisto_bustools_locations = "kallisto-bustools_locations.tsv"
	}
	runtime {
		docker: "~{alexandria_docker}"
		preemptible: "~{preemptible}"
		zones: "~{zones}"
	}
}

task setup_from_bcl2fastq {
	input {
		String bucket_slash
		File alexandria_sheet
		Array[File] bcl2fastq_sheets
		String zones
		Int preemptible
		String alexandria_docker
	}
	command <<<
		set -e
		python /alexandria/scripts/setup_from_bcl2fastq.py \
			-t=Kallisto-Bustools \
			-b=~{sep=' ' bcl2fastq_sheets} \
			-i=~{alexandria_sheet}
	>>>
	output {
		File kallisto_bustools_locations = "kallisto-bustools_locations.tsv"
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
		File alexandria_sheet
		String reference
		String bucket_slash
		String kallisto_bustools_output_path_slash
		String cumulus_output_path_slash
		String alexandria_docker
		Int preemptible
		String zones
		Array[String?]? count_output_paths
	}
	command <<<
		set -e
		python /alexandria/scripts/setup_cumulus.py \
			-i=~{alexandria_sheet} \
			-t=Kallisto-Bustools \
			-g=~{bucket_slash} \
			~{true="--check_inputs" false='' check_inputs} \
			-r=~{reference} \
			-o=~{kallisto_bustools_output_path_slash} # Should make optional if MTX_Path given
		gsutil cp count_matrix.csv ~{bucket_slash}~{cumulus_output_path_slash}
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
		File alexandria_sheet
		String cumulus_output_path_slash
		Array[File]? output_scp_files
		String bucket_slash
		String alexandria_docker
		Int preemptible
		String zones
	}
	command <<<
		set -e
		printf "~{sep='\n' output_scp_files}" >> output_scp_files.txt
		python /alexandria/scripts/scp_outputs.py \
			-t Kallisto-Bustools \
			-i ~{alexandria_sheet} \
			-s output_scp_files.txt
		gsutil cp alexandria_metadata.txt ~{bucket_slash}~{cumulus_output_path_slash}
	>>>
	output {
		File alexandria_metadata = "alexandria_metadata.txt"
		File cumulus_metadata = glob("*scp.metadata.txt")[0]
		File fitsne_coords = glob("*scp.X_fitsne.coords.txt")[0]
		File dense_matrix = glob("*scp.expr.txt")[0]
		File pca_coords = glob("*scp.X_pca.coords.txt")[0]
	}
	runtime {
		docker: "~{alexandria_docker}"
		preemptible: "~{preemptible}"
		zones: "~{zones}"
	}
}
