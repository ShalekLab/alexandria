import "https://api.firecloud.org/ga4gh/v1/tools/scCloud:cellranger_workflow/versions/3/plain-WDL/descriptor" as cellranger
import "https://api.firecloud.org/ga4gh/v1/tools/scCloud:scCloud/versions/18/plain-WDL/descriptor" as sc 

workflow cellranger_scCloud_workflow {
	# 5 - 8 columns (Sample, Reference, Flowcell, Lane, Index, [Chemistry, DataType, FeatureBarcodeFile]). gs URL
	File input_csv_file

	# Output bucket
  	String bucket

  	String sc_cloud_output_prefix

	# Output object
	String bucket_object

	String output_directory = bucket + "/" + bucket_object

	# If run cellranger mkfastq
	Boolean run_mkfastq = true
	# If run cellranger count
	Boolean run_count = true

	# Force pipeline to use this number of cells, bypassing the cell detection algorithm, mutually exclusive with expect_cells.
	Int? force_cells

	# Expected number of recovered cells. Mutually exclusive with force_cells
	Int? expect_cells

	# 2.1.1, 2.2.0, 3.0.0, or 3.0.2
	String? cellranger_version = "2.2.0"

	String? sccloud_version = "0.6.0"

	# Number of cpus per scCloud job
	Int? sc_cloud_cpu = 64
    String? sc_cloud_memory = "200G"
    Int? sc_cloud_disk_space = 100

	call cellranger.cellranger_workflow as crw {
		input:
			input_csv_file=input_csv_file,
			output_directory=output_directory,
			run_mkfastq=run_mkfastq,
			run_count=run_count,
			force_cells=force_cells,
			expect_cells=expect_cells,
			cellranger_version=cellranger_version,
	}

	if(run_count) {
		call sc.scCloud as sc {
			input:
				input_count_matrix_csv=crw.count_matrix,
				output_name=output_directory + "/"  + sc_cloud_output_prefix,
				generate_scp_outputs = true,
				output_dense=true,
				genome="",
				num_cpu=sc_cloud_cpu,
				memory=sc_cloud_memory,
				disk_space =sc_cloud_disk_space,
				sccloud_version=sccloud_version
		}
		call list_scp_outputs {
			input:
				sccloud_version=sccloud_version,
				output_scp_files=sc.output_scp_files
		}
	}

	output {
		Array[File]? coordinate_files = list_scp_outputs.coordinate_files
		File? metadata = list_scp_outputs.metadata
		File? dense_matrix = list_scp_outputs.dense_matrix
 	}

}


task list_scp_outputs {
	String sccloud_version
	Array[String] output_scp_files

	command {
		set -e

		python <<CODE

		files = '${sep="," output_scp_files}'.split(',')
		with open('coordinates.txt', 'wt') as c, open('metadata.txt', 'wt') as m, open('dense_matrix.txt', 'wt') as d:
			for file in files:
				if file.endswith(".coords.txt"):
					c.write(file + '\n')
				elif file.endswith(".scp.metadata.txt"):
					m.write(file + '\n')
				elif file.endswith(".scp.expr.txt"):
					d.write(file + '\n')
		CODE
	}

	output {
		Array[File] coordinate_files = read_lines('coordinates.txt')
		File metadata = read_lines('metadata.txt')[0]
		File dense_matrix = read_lines('dense_matrix.txt')[0]
	}

	runtime {
		docker: "regevlab/sccloud-${sccloud_version}"
		preemptible: 2
	}
}
