#import "https://api.firecloud.org/ga4gh/v1/tools/dropseq_workflow_modded:dropseq_workflow_modded/versions/14/plain-WDL/descriptor" as dropseq
#import "https://api.firecloud.org/ga4gh/v1/tools/scCloud:scCloud/versions/23/plain-WDL/descriptor" as sc

# TODO: WILL NOT WORK UNTIL SP CHECKS TURNED INTO GLOB/RE/OS CHECKS

#Read through for these SIX test cases:
#	bcl dropseq scCloud
#	bcl dropseq
#	bcl scCloud
#	fastq dropseq sccloud
#	fastq dropseq
#	fastq scCloud
# % indicates this change needs to be made

workflow dropseq_scCloud_workflow {
	
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
	#File reference
	String reference

	# TODO: Support overriding of setup_scCloud with user-inputted count_matrix.csv
	File? count_matrix_override
	# TODO REMOVE THIS AND INCORPORATE INTO A DOCKERFILE.
	File? metadata_type_map = bucket_stripped+"/metadata_type_map.tsv"

	# At least one of the following Booleans must be set as true
	# Set true to run alignment by dropseq
	Boolean run_dropseq
	Boolean is_bcl
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

	if (run_dropseq) {
		call setup_dropseq { # Check user inputs .csv and create dropseq_locations.tsv for dropseq and/or count_matrix.csv for scCloud
			input:
				bucket_stripped=bucket_stripped,
				run_dropseq=run_dropseq,
				is_bcl=is_bcl,
				input_csv_file=input_csv_file,
				metadata_type_map=metadata_type_map,
				reference=reference,
				dropseq_output_directory_stripped=dropseq_output_directory_stripped,
				dropseq_default_directory_stripped=dropseq_default_directory_stripped,
				dropseq_tools_version=dropseq_tools_version
			#output:
			#	File dropseq_locations = "dropseq_locations.tsv"
		}
		#call dropseq.dropseq_workflow as dropseq {
		call dsw as dropseq {
			input:
				input_csv_file=setup_dropseq.dropseq_locations, #.csv is a misnomer, actually a .tsv
				run_bcl2fastq=is_bcl,
				output_directory=dropseq_output_directory_stripped,
				reference=reference,
				drop_seq_tools_version=dropseq_tools_version # Varname drop_seq_tools_version in the subwdl.
			#output:
			#	Array[String?]? dge_summaries
			#	Array[String?]? sample_IDs
		}
	}

	if (run_scCloud) {
		call setup_scCloud{
			input: 
				dge_summaries=dropseq.dge_summaries, #OPTIONAL
				sample_IDs=dropseq.sample_IDs, #OPTIONAL
				run_dropseq=run_dropseq, # If false then do general setup and build count_matrix from dirs in dropseq_output_directory_stripped?
				is_bcl=is_bcl, #is_bcl? If dropseq=false and =true then build count_matrix from sample_sheets
				#count_matrix_override=count_matrix_override, #OPTIONAL, allow override of count_matrix, don't support until later.
				input_csv_file=input_csv_file,
				metadata_type_map=metadata_type_map,
				reference=reference,
				sccloud_version=scCloud_version,
				bucket_stripped=bucket_stripped,
				dropseq_output_directory_stripped=dropseq_output_directory_stripped,
				scCloud_output_directory_stripped=scCloud_output_directory_stripped,
			#output:
			#	String/File count_matrix
		}
		#call sc.scCloud as scCloud {
		call scw as scCloud {
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
				sccloud_version=scCloud_version # Varname sccloud in the subwdl.
		}
		call scp_outputs {
			input:
				input_csv_file=input_csv_file,
				metadata_type_map=metadata_type_map,
				scCloud_version=scCloud_version,
				scCloud_output_directory_stripped=scCloud_output_directory_stripped,
				output_scp_files=scCloud.output_scp_files,
				cluster_file=scCloud_output_directory_stripped+'/'+scCloud_output_prefix+".scp.X_fitsne.coords.txt"
		}
	}
	output {
		Array[File]? coordinate_files = scp_outputs.coordinate_files
		File? metadata = scp_outputs.metadata
		File? dense_matrix = scp_outputs.dense_matrix
		File? alexandria_metadata = scp_outputs.alexandria_metadata
	}
}

task setup_dropseq {
	String bucket_stripped
	Boolean run_dropseq
	Boolean is_bcl
	File input_csv_file
	File metadata_type_map
	String reference
	String dropseq_output_directory_stripped
	String dropseq_default_directory_stripped
	String dropseq_tools_version
	
	command {
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import sys
		import pandas as pd
		import numpy as np
		import subprocess as sp

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

		# TODO: Address edge case of having more than one R1/R2/BCL_Path?
		is_bcl="${true='True' false='False' is_bcl}"
		dsl = pd.DataFrame()
		if is_bcl is True:
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
				'''
				try:
					sp.check_call(args=["gsutil", "ls", fastq_path], stdout=sp.DEVNULL) # Checks existence on gcloud and raises error
					path = sp.Popen(args=["gsutil", "ls", fastq_path], stdout=sp.PIPE) # Runs it again for stdout to path
				except sp.CalledProcessError: # Error potentially raised by check_call.
					sys.exit("ERROR: Checked path \""+fastq_path+"\", was not found.") # TODO: Give a more detailed error message here!
				path = (path.communicate())[0].strip().decode('ascii') # Processes the byte literal output into a stripped string #should strip be called after decode?
				return path
				'''
				candidates = glob.glob(fastq_path)
				if candidates: return candidates[0]
				else: sys.exit("ERROR: Checked path \""+fastq_path+"\", was not found.")
			dsl["R1_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(csv, location_override, "R1"))
			dsl["R2_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(csv, location_override, "R2"))
		dsl.to_csv("dropseq_locations.tsv", sep='\t', header=None, index=False)

		CODE

		gsutil -q -m cp dropseq_locations.tsv ${dropseq_output_directory_stripped}/
	}
	output {
		File dropseq_locations = "dropseq_locations.tsv"
	}
	#runtime {
	#	docker: "regevlab/dropseq-${dropseq_tools_version}"
	#	preemptible: 2
	#}
}

#DUMMY TASK for testing
task dsw {
	File input_csv_file #.csv is a misnomer, actually a .tsv
	Boolean run_bcl2fastq
	String output_directory
	String reference
	String drop_seq_tools_version
	
	command {
		echo "Run dsw"
	}
	output {
		Array[String] dge_summaries = ["${output_directory}/B0_2/B0_2.dge.txt.gz"]
		Array[String] sample_IDs = ["B0_2"]
	}
	#runtime {
	#	docker: "regevlab/dropseq-${drop_seq_tools_version}"
	#	preemptible: 2
	#}
}

task setup_scCloud {
	Array[String?]? dge_summaries
	Array[String?]? sample_IDs
	Boolean run_dropseq # If false then do general setup and build count_matrix from dirs in dropseq_output_directory_stripped?
	Boolean is_bcl #is_bcl? If dropseq=false and =true then build count_matrix from sample_sheets
	#File? count_matrix_override
	File input_csv_file
	File metadata_type_map
	String reference
	String bucket_stripped
	String sccloud_version
	String dropseq_output_directory_stripped
	String scCloud_output_directory_stripped
	
	command <<<
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import sys
		import pandas as pd
		import numpy as np
		import subprocess as sp

		run_dropseq="${true='True' false='False' run_dropseq}"
		is_bcl="${true='True' false='False' is_bcl}"
		
		# TODO: Support metadata appending for BCL samples required for visualization.
		if is_bcl: sys.exit("ERROR: Appending of metadata for BCL samples is not yet supported. You can build a new input_csv_file for the produced fastq's and run with run_dropseq=false, is_bcl=false, and run_scCloud=true.")

		# TODO: Support count_matrix_override?
		# if "count_matrix_override" is '': # Indent everything after. # RE-ADD THE INTERPOLATION TO THIS LINE.
		
		if run_dropseq is True:
			samples = "${sep=',' sample_IDs}".split(',')
			dge_summaries = "${sep=',' dge_summaries}".split(',')
			samples = list(filter(lambda x: x.strip() != '', samples))
			dge_summaries = list(filter(lambda x: x.strip() != '', dge_summaries))
			cm = pd.DataFrame({"Sample":samples, "Location":dge_summaries})
		else: # scCloud solo
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

			# TODO: Support metadata appending for BCL samples required for visualization.
			#if is_bcl:
				# find all sample sheets based on csv
				# merge all sample sheet samples into a count_matrix.

			cm = pd.DataFrame()
			cm["Sample"] = csv["Sample"]
			def get_dge_location(element, run_dropseq):
				location = "${dropseq_output_directory_stripped}/"+element+'/'+element+"_dge.txt.gz"
				try: sp.check_call(args=["gsutil", "ls", location], stdout=sp.DEVNULL)
				except sp.CalledProcessError: sys.exit("ERROR: "+location+" was not found.")
				return location
			cm["Location"] = csv["Sample"].apply(func=get_dge_location, args=(run_dropseq,))	
		cm.to_csv("count_matrix.csv", header=True, index=False) # Scope might need to change if count_matrix_override is supported.
		
		# TODO: Support count_matrix_override?		
		#else: #validate countmatrixoverride.

		CODE
		
		#gsutil -q -m cp count_matrix.csv ${scCloud_output_directory_stripped}
		cp count_matrix.csv ${scCloud_output_directory_stripped}
	>>>
	output {
		#File count_matrix = if "${count_matrix_override}" != '' then "${count_matrix_override}" else "count_matrix.csv"
		File count_matrix = "count_matrix.csv" 
	}
	#runtime {
	#	docker: "regevlab/sccloud-${sccloud_version}"
	#	preemptible: 2
	#}
}

#DUMMY TASK for testing
task scw {
	File input_count_matrix_csv
	String output_name
	Boolean is_dropseq
	String genome
	Boolean generate_scp_outputs
	Boolean output_dense
	Int? num_cpu
	String? memory
	Int? disk_space
	String sccloud_version

	command {
		echo "Run scw"
	}
	output {
		#Array[File] output_scp_files = ["sco.scp.expr.txt", "sco.scp.metadata.txt", "sco.scp.X_diffmap_pca.coords.txt", "sco.scp.X_fitsne.coords.txt"]
		Array[String] output_scp_files = ["/Users/jggatter/Desktop/Alexandria/local/junk/60/scCloud/sco.scp.expr.txt", "/Users/jggatter/Desktop/Alexandria/local/junk/60/scCloud/sco.scp.metadata.txt", "/Users/jggatter/Desktop/Alexandria/local/junk/60/scCloud/sco.scp.X_diffmap_pca.coords.txt", "/Users/jggatter/Desktop/Alexandria/local/junk/60/scCloud/sco.scp.X_fitsne.coords.txt"]
	}
	#runtime {
	#	docker: "regevlab/sccloud-${sccloud_version}"
	#	preemptible: 2
	#}
}

task scp_outputs {
	File input_csv_file
	File metadata_type_map
	String scCloud_version
	String scCloud_output_directory_stripped
	Array[File] output_scp_files
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

		# TODO: Make the bottom two chunks a separate task that can run concurrently with this one?
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
			# TODO: Type cast data to validate that numeric is int/float, group is whatever.
			if element == "group": return mtm.loc[mtm.attribute == metadata, "type"].to_string(index=False).strip() #For TYPE row, search for type in map
			else: return csv.loc[csv.Sample == element, metadata].to_string(index=False).strip()
		for metadata in csv.columns:
			if metadata == "Sample": continue
			amd[metadata] = amd["Channel"].apply(func=get_metadata, args=(csv, metadata, mtm))
			amd.to_csv("alexandria_metadata.txt", sep='\t', index=False)

		#gsutil -q -m cp alexandria_metadata.txt ${scCloud_output_directory_stripped}
		cp alexandria_metadata.txt ${scCloud_output_directory_stripped}/

	}
	output {
		Array[File] coordinate_files = read_lines('coordinates.txt')
		File metadata = read_lines('metadata.txt')[0]
		File dense_matrix = read_lines('dense_matrix.txt')[0]
		File alexandria_metadata = read_lines("alexandria_metadata.txt")[0]
	}
	#runtime {
	#	docker: "regevlab/sccloud-${scCloud_version}"
	#	preemptible: 2
	#}
}
runtime