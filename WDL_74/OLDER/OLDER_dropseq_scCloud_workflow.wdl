import "https://api.firecloud.org/ga4gh/v1/tools/dropseq_workflow_modded:dropseq_workflow_modded/versions/14/plain-WDL/descriptor" as dropseq
import "https://api.firecloud.org/ga4gh/v1/tools/scCloud:scCloud/versions/23/plain-WDL/descriptor" as sc
#import "dropseq_workflow_modded.wdl" as dropseq
#import "scCloud.23.wdl" as sc

#TODO: Really question which variables need to be optional(?).
#TODO: maybe use some if then else statements to set variables.

#TODO: Preparing integration to Alexandria:
	#- Getting output from scCloud into the correct format
	#- Deciding which input arguments to expose
	#-!!! We decided we wanted to generate cell level metadata files even if scCloud is not run
	#- Create unique Dockerfile???
	#	- that merges dropseq and scCloud dockerfiles.
	#	- that contains all subworkflows and make dropseq_scCloud call those? Is that even possible?

workflow dropseq_scCloud_workflow {
	
	#TODO!! fix workflow order such that scCloud does not run until AFTER dropseq completes. gcm can run concurrently.

	# User-inputted .csv file that contains in whatever order:
	#	(REQUIRED) the 'Sample' column, 
	#	(OPTIONAL) both 'R1_Path' and 'R2_Path' columns
	#	(OPTIONAL) 'BCL_Path' column
	#	(OPTIONAL) other metadata columns that currently aren't used/outputted by the workflow
	File input_csv_file

	#The file name assigned to the scCloud outputs.
	String scCloud_output_prefix = "sco"

	# Output object, seems to be a path/to/dir in the bucket.
	# TODO: Test if can point to non-workspace buckets.
	String bucket
	String bucket_stripped = sub(bucket, "/+$", "")
	String dropseq_output_directory
	String dropseq_output_directory_stripped = bucket_stripped+'/'+sub(dropseq_output_directory, "/+$", "")
	String scCloud_output_directory
	String scCloud_output_directory_stripped = bucket_stripped+'/'+sub(scCloud_output_directory, "/+$", "")
	String dropseq_default_directory
	String dropseq_default_directory_stripped = bucket_stripped+'/'+sub(dropseq_default_directory, "/+$", "")

	# "hg19" or another reference.
	File reference

	# TODO REMOVE THIS AND INCORPORATE INTO A DOCKERFILE.
	File? metadata_type_map = bucket_stripped+"/metadata_type_map.tsv"

	# At least one of the following Booleans must be set as true
	# Set true to run alignment by dropseq
	Boolean run_dropseq
	Boolean run_bcl2fastq
	#TODO: Support run_dropest input to scCloud
	# Set true to run clustering/visualization by scCloud
	Boolean run_scCloud

	# Version numbers to select the specified runtime dockerfile.
	String? dropseq_tools_version = "2.3.0"
	String? scCloud_version = "0.8.0"

	# Number of cpus per scCloud job
	Int? scCloud_cpu = 64
	String? scCloud_memory = "200G"
	Int? scCloud_disk_space = 100

	call setup { # Check user inputs .csv and create dropseq_locations.tsv for dropseq and/or count_matrix.csv for scCloud
		input:
			bucket_stripped=bucket_stripped,
			run_dropseq=run_dropseq,
			run_bcl2fastq=run_bcl2fastq,
			run_scCloud=run_scCloud,
			input_csv_file=input_csv_file,
			metadata_type_map=metadata_type_map,
			reference=reference,
			dropseq_output_directory_stripped=dropseq_output_directory_stripped,
			scCloud_output_directory_stripped=scCloud_output_directory_stripped,
			dropseq_default_directory_stripped=dropseq_default_directory_stripped,
			dropseq_tools_version=dropseq_tools_version
	}

	if (run_dropseq && run_scCloud){
		call dropseq.dropseq_workflow as dropseq {
			input:
				input_csv_file=setup.dropseq_locations, #.csv is a misnomer, actually a .tsv
				run_bcl2fastq=run_bcl2fastq,
				output_directory=dropseq_output_directory_stripped,
				reference=reference,
				drop_seq_tools_version=dropseq_tools_version
		}
		call setup_scCloud{
			input: 
				dge_summaries=dropseq.dge_summaries,
				sample_IDs=dropseq.sample_IDs,
				run_bcl2fastq=run_bcl2fastq,
				dropseq_tools_version=dropseq_tools_version,
				scCloud_output_directory_stripped=scCloud_output_directory_stripped,
				count_matrix_path=setup.count_matrix
		}
		call sc.scCloud as scCloud {
			input:
				input_count_matrix_csv=setup_scCloud.count_matrix,
				output_name=scCloud_output_directory_stripped + '/' + scCloud_output_prefix,
				is_dropseq=true,
				genome=reference,
				generate_scp_outputs=true,
				output_dense=true,
				num_cpu=scCloud_cpu,
				memory=scCloud_memory,
				disk_space=scCloud_disk_space,
				sccloud_version=scCloud_version
		}
		call scp_outputs {
			input:
				input_csv_file=input_csv_file,
				metadata_type_map=metadata_type_map,
				dropseq_tools_version=dropseq_tools_version,
				scCloud_output_directory_stripped=scCloud_output_directory_stripped,
				output_scp_files=scCloud.output_scp_files,
				cluster_file=scCloud_output_directory_stripped+'/'+scCloud_output_prefix+".scp.X_fitsne.coords.txt"
		}
	}
	if (run_dropseq && !run_scCloud){
		call dropseq.dropseq_workflow as dropseq_solo {
			input:
				input_csv_file=setup.dropseq_locations,
				run_bcl2fastq=run_bcl2fastq,
				output_directory=dropseq_output_directory_stripped,
				reference=reference,
				drop_seq_tools_version=dropseq_tools_version
		}
	}
	if (!run_dropseq && run_scCloud){
		call sc.scCloud as scCloud_solo {
			input:
				input_count_matrix_csv=setup.count_matrix,
				output_name=scCloud_output_directory_stripped+'/'+scCloud_output_prefix,
				is_dropseq=true,
				genome=reference,
				generate_scp_outputs=true,
				output_dense=true,
				num_cpu=scCloud_cpu,
				memory=scCloud_memory,
				disk_space=scCloud_disk_space,
				sccloud_version=scCloud_version
		}
		call scp_outputs as scp_outputs_solo{
			input:
				input_csv_file=input_csv_file,
				metadata_type_map=metadata_type_map,
				dropseq_tools_version=dropseq_tools_version,
				scCloud_output_directory_stripped=scCloud_output_directory_stripped,
				output_scp_files=scCloud_solo.output_scp_files,
				cluster_file=scCloud_output_directory_stripped+'/'+scCloud_output_prefix+".scp.X_fitsne.coords.txt"
		}
	}
	#TODO ask Cromwell team about aliasing to resolve the issue below.
	output {
		Array[File]? coordinate_files = scp_outputs.coordinate_files
		File? metadata = scp_outputs.metadata
		File? dense_matrix = scp_outputs.dense_matrix
		File? alexandria_metadata = scp_outputs.alexandria_metadata
		
		Array[File]? scCloud_solo_coordinate_files = scp_outputs_solo.coordinate_files
		File? scCloud_solo_metadata = scp_outputs_solo.metadata
		File? scCloud_solo_dense_matrix = scp_outputs_solo.dense_matrix
		File? scCloud_solo_alexandria_metadata = scp_outputs_solo.alexandria_metadata
	}
}

#TODO Consider dividing into two separate tasks, one for setting up dropseq and the other for scCloud
task setup {

	#TODO: Error checking:
	#--	Checking inputs for correct value types, files that exist and are formatted correctly (metadata validation script from Jean), 
	#	reference genome that exists, input parameters that do not conflict with each other. If only scCloud is run, check that dropseq 
	#	results are in the expected location.
	#-- Check that the pipeline fails in an interpretable and elegant way (i.e. does not keep running if a previous step fails and sends
	#	an interpretable error message to users)
	#--	In error messages, include link to input description/wiki for this pipeline so users can attempt to troubleshoot on their own
	#--	Special characters and spaces in sample names - are there restrictions on this?
	#--	How does scCloud deal with multiple samples? Desired behavior would be to combine them into a single analysis as a default and 
	#	include an option for separate analyses - this may lead to the need to do more combining/splitting of files to prepare the i/o's.
	#-- Will same output dirs override dropseq_locations.tsv's and count_matrix.csv's?

	Boolean run_dropseq
	Boolean run_bcl2fastq
	Boolean run_scCloud
	File input_csv_file
	File metadata_type_map
	String reference
	String bucket_stripped
	String dropseq_output_directory_stripped
	String scCloud_output_directory_stripped
	String dropseq_default_directory_stripped
	String dropseq_tools_version

	command {
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import os
		import sys
		import pandas as pd
		import numpy as np
		import subprocess as sp

		run_dropseq=False
		run_bcl2fastq=False
		run_scCloud=False
		if "${run_dropseq}" is "true": run_dropseq=True
		if "${run_bcl2fastq}" is "true": run_bcl2fastq=True
		if "${run_scCloud}" is "true": run_scCloud=True

		if not run_dropseq and not run_scCloud:
			sys.exit("ERROR: At least one of run_dropseq and run_scCloud must be set to true.")
		
		try: sp.check_call(args=["gsutil", "ls", "${bucket_stripped}"], stdout=sp.DEVNULL)
		except sp.CalledProcessError: sys.exit("ERROR: Bucket \"${bucket_stripped}\" was not found.")

		#TODO: Support hg38 and custom json reference files.
		valid_references=["hg19", "mm10", "hg19_mm10", "mmul_8.0.1"]
		if "${reference}" not in valid_references:
			sys.exit("ERROR: ${reference} does not match a valid reference: (\"hg19\", \"mm10\", \"hg19_mm10\", and \"mmul_8.0.1\").")
		
		csv = pd.read_csv("${input_csv_file}", dtype=str, header=0)
		for col in csv.columns: csv[col] = csv[col].str.strip()
		if "Sample" not in csv.columns: sys.exit("ERROR: Required column 'Sample' was not found in ${input_csv_file}.")
		csv = csv.dropna(subset=['Sample'])

		mtm = pd.read_csv("${metadata_type_map}", dtype=str, header=0, sep='\t')
		for col in csv.columns:
			if col == "Sample" or col == "R1_Path" or col == "BCL_Path" or col == "R2_Path": continue
			if not col in mtm["attribute"].tolist(): sys.exit("ERROR: Metadata \""+col+"\" is not a valid metadata type")

		if run_dropseq is True:
			dsl = pd.DataFrame()
			if run_bcl2fastq is True:
				location_override = False
				if "BCL_Path" in csv.columns: location_override = True
				else: csv["BCL_Path"] = csv["Sample"].replace(csv["Sample"], np.nan)
				def get_bcl_location(element, csv, location_override):
					path = csv.loc[csv.Sample == element, "BCL_Path"].to_string(index=False).strip()
					if location_override is False or path == "NaN":
						BCL_path = "${dropseq_default_directory_stripped}/"+element
					else: BCL_path = "${bucket_stripped}/"+path
					try: sp.check_call(args=["gsutil", "ls", BCL_path], stdout=sp.DEVNULL)
					except sp.CalledProcessError: sys.exit("ERROR: "+BCL_path+" was not found.")
					return BCL_path
				dsl["BCL_Path"] = csv["Sample"].apply(func=get_bcl_location, args=(csv, location_override))
			else:
				dsl["Sample"] = csv["Sample"]
				location_override = False
				if "R1_Path" in csv.columns and "R2_Path" in csv.columns: location_override = True #TODO: consider adding confirmation message, "Will be overriding from R1_Path and R2_Path"
				else: csv["R1_Path"] = csv["R2_Path"] = csv["Sample"].replace(csv["Sample"], np.nan)
				def get_fastq_location(element, csv, location_override, read):
					path = csv.loc[csv.Sample == element, read+"_Path"].to_string(index=False).strip()
					if location_override is False or path == "NaN":
						fastq_path = "${dropseq_default_directory_stripped}/"+element+'*'+read+"*.fastq.gz"
					else: fastq_path = "${bucket_stripped}/"+path
					try:
						sp.check_call(args=["gsutil", "ls", fastq_path], stdout=sp.DEVNULL) # Checks existence on gcloud and raises error
						path = sp.Popen(args=["gsutil", "ls", fastq_path], stdout=sp.PIPE) # Runs it again for stdout to path
					except sp.CalledProcessError: # Error potentially raised by check_call.
						sys.exit("ERROR: Checked path \""+fastq_path+"\", was not found.") # TODO: Give a more detailed error message here!
					path = (path.communicate())[0].strip().decode('ascii') # Processes the byte literal output into a stripped string #should strip be called after decode?
					return path
				dsl["R1_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(csv, location_override, "R1"))
				dsl["R2_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(csv, location_override, "R2"))
			dsl.to_csv("dropseq_locations.tsv", sep='\t', header=None, index=False)

		#TODO: Move this to setup_scCloud and restructure the .wdl
		if run_scCloud is True and run_dropseq is False and run_bcl2fastq is False: #if rundropseq is True, setup_scCloud will produce count_matrix.csv.
			cm = pd.DataFrame()
			cm["Sample"] = csv["Sample"]
			def get_dge_location(element, run_dropseq):
				location = "${dropseq_output_directory_stripped}/"+element+'/'+element+"_dge.txt.gz"
				if not run_dropseq:
					try: sp.check_call(args=["gsutil", "ls", location], stdout=sp.DEVNULL)
					except sp.CalledProcessError: sys.exit("ERROR: "+location+" was not found.")
				return location
			cm["Location"] = csv["Sample"].apply(func=get_dge_location, args=(run_dropseq,))	
			cm.to_csv("count_matrix.csv", header=True, index=False)
		CODE

		if [ -e "dropseq_locations.tsv" ]; then gsutil -q -m cp dropseq_locations.tsv ${dropseq_output_directory_stripped}/; fi
		if [ -e "count_matrix.csv" ]; then gsutil -q -m cp count_matrix.csv ${scCloud_output_directory_stripped}/; fi
	}
	output {
		String? dropseq_locations = "${dropseq_output_directory_stripped}/dropseq_locations.tsv"
		String? count_matrix = "${scCloud_output_directory_stripped}/count_matrix.csv"
	}
	runtime {
		docker: "regevlab/dropseq-${dropseq_tools_version}"
		preemptible: 2
	}
}

# TODO: Update all subworkflows to WDL 2.0 upon its release and remove bridge.
task setup_scCloud {
	
	Array[String?]? dge_summaries
	Array[String?]? sample_IDs
	Boolean run_bcl2fastq
	String count_matrix_path #Was type File.
	String scCloud_output_directory_stripped
	String dropseq_tools_version

	command<<<
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import pandas as pd

		if "${run_bcl2fastq}" is "true":
			samples = "${sep=',' sample_IDs}".split(',')
			dge_summaries = "${sep=',' dge_summaries}".split(',')
			samples = list(filter(lambda x: x.strip() != '', samples))
			dge_summaries = list(filter(lambda x: x.strip() != '', dge_summaries))
			cm = pd.DataFrame({"Sample":samples, "Location":dge_summaries})
			cm.to_csv("count_matrix.csv", header=True, index=False)
		
		gsutil -q -m cp count_matrix.csv ${scCloud_output_directory_stripped}
	>>>
	output {
		String? count_matrix = "${scCloud_output_directory_stripped}/count_matrix.csv"
	}
	runtime {
		docker: "regevlab/dropseq-${dropseq_tools_version}"
		preemptible: 2
	}
}

task scp_outputs {
	
	String dropseq_tools_version
	Array[String] output_scp_files
	File input_csv_file
	File metadata_type_map
	String scCloud_output_directory_stripped
	File cluster_file

	command {
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import pandas as pd

		files = '${sep="," output_scp_files}'.split(',')
		with open('coordinates.txt', 'wt') as c, open('metadata.txt', 'wt') as m, open('dense_matrix.txt', 'wt') as d:
			for file in files:
				if file.endswith(".coords.txt"):
					c.write(file + '\n')
				elif file.endswith(".scp.metadata.txt"):
					m.write(file + '\n')
				elif file.endswith(".scp.expr.txt"):
					d.write(file + '\n')

		#TODO: Make the bottom two chunks a separate task that can run concurrently with this one. Does this affect workflow outputs?
		amd = pd.read_csv("${cluster_file}", dtype=str, sep='\t', header=0)
		amd = amd.drop(columns=['X','Y'])
		def get_sample(element):
			if element == "TYPE": return "group"
			else: return '-'.join(element.split('-')[:-1])
		amd.insert(1, "Channel", pd.Series(amd["NAME"].map(get_sample)))

		csv = pd.read_csv("${input_csv_file}", dtype=str, header=0).dropna(subset=['Sample'])
		mtm = pd.read_csv("${metadata_type_map}", dtype=str, header=0, sep='\t')
		if "R1_Path" in csv.columns and "R2_Path" in csv.columns: csv = csv.drop(columns=["R1_Path", "R2_Path"])
		if "BCL_Path" in csv.columns: csv = csv.drop(columns=["BCL_Path"])
		def get_metadata(element, csv, metadata, mtm):
			if element == "group": return mtm.loc[mtm.attribute == metadata, "type"].to_string(index=False).strip() #For TYPE row, search for type in map
			else: return csv.loc[csv.Sample == element, metadata].to_string(index=False).strip()
		for metadata in csv.columns:
			if metadata == "Sample": continue
			amd[metadata] = amd["Channel"].apply(func=get_metadata, args=(csv, metadata, mtm))
			amd.to_csv("alexandria_metadata.txt", sep='\t', index=False)

		gsutil -q -m cp alexandria_metadata.txt ${scCloud_output_directory_stripped}/
	}
	output {
		Array[File] coordinate_files = read_lines('coordinates.txt')
		File metadata = read_lines('metadata.txt')[0]
		File dense_matrix = read_lines('dense_matrix.txt')[0]
		File alexandria_metadata = read_lines("alexandria_metadata.txt")[0]
	}
	runtime {
		docker: "regevlab/dropseq-${dropseq_tools_version}"
		preemptible: 2
	}
}