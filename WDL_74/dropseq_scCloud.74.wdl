# By jgatter [at] broadinstitute.org, created August 23rd, 2019
# https://portal.firecloud.org/?return=terra#methods/dropseq_scCloud_workflow/dropseq_scCloud_workflow/66/wdl
# Incorporates subworkflows made by jgould [at] broadinstitute.org

import "https://api.firecloud.org/ga4gh/v1/tools/dropseq_workflow_modded:dropseq_workflow_modded/versions/19/plain-WDL/descriptor" as dropseq
import "https://api.firecloud.org/ga4gh/v1/tools/scCloud:scCloud/versions/23/plain-WDL/descriptor" as sc

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
	# TODO! Make every task in the file work for empty strings. Probably should keep below lines but append +'/' after the sub().
	String bucket
	String bucket_stripped = sub(bucket, "/+$", "")
	String dropseq_output_directory
	String dropseq_output_directory_stripped = bucket_stripped+'/'+sub(dropseq_output_directory, "/+$", "")
	String scCloud_output_directory
	String scCloud_output_directory_stripped = bucket_stripped+'/'+sub(scCloud_output_directory, "/+$", "")
	String dropseq_default_directory
	String dropseq_default_directory_stripped = bucket_stripped+'/'+sub(dropseq_default_directory, "/+$", "")

	# "hg19" or another reference.
	String reference

	# At least one of the following Booleans must be set as true
	# Set true to run alignment by dropseq
	Boolean run_dropseq
	Boolean is_bcl
	#TODO: Support run_dropest input to scCloud
	# Set true to run clustering/visualization by scCloud
	Boolean run_scCloud

	# Version numbers to select the specified runtime dockerfile.
	String? dropseq_tools_version = "2.3.0"
	String? scCloud_version = "0.8.0:v1.0"
	String alexandria_version = "0.1"
	Int? preemptible = 2
	String? zones = "us-east1-d us-west1-a us-west1-b"

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
				reference=reference,
				dropseq_output_directory_stripped=dropseq_output_directory_stripped,
				dropseq_default_directory_stripped=dropseq_default_directory_stripped,
				preemptible=preemptible,
				alexandria_version=alexandria_version
			#output:
			#	File dropseq_locations = "dropseq_locations.tsv"
		}
		call dropseq.dropseq_workflow as dropseq {
		#call ds_dummy as dropseq {
			input:
				input_csv_file=setup_dropseq.dropseq_locations, #.csv is a misnomer, actually a .tsv
				run_bcl2fastq=is_bcl,
				output_directory=dropseq_output_directory_stripped,
				reference=reference,
				zones=zones,
				preemptible=preemptible,
				drop_seq_tools_version=dropseq_tools_version # Varname drop_seq_tools_version in the subwdl.
			#output:
			#	Array[File?]? dge
			#	Array[File?]? sample_IDs
		}
	}

	if (run_scCloud) {
		call setup_scCloud{
			input: 
				dges=dropseq.dge, #OPTIONAL
				sample_IDs=dropseq.sample_IDs, #OPTIONAL
				run_dropseq=run_dropseq, # If false then do general setup and build count_matrix from dirs in dropseq_output_directory_stripped?
				#is_bcl=is_bcl, #is_bcl? If dropseq=false and =true then build count_matrix from sample_sheets
				#count_matrix_override=count_matrix_override, #OPTIONAL, allow override of count_matrix, don't support until later?
				input_csv_file=input_csv_file,
				reference=reference,
				alexandria_version=alexandria_version,
				preemptible=preemptible,
				bucket_stripped=bucket_stripped,
				dropseq_output_directory_stripped=dropseq_output_directory_stripped,
				scCloud_output_directory_stripped=scCloud_output_directory_stripped,
			#output:
			#	File count_matrix
		}
		call sc.scCloud as scCloud {
		#call sc_dummy as scCloud {
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
				preemptible=preemptible,
				zones=zones,
				sccloud_version=scCloud_version # Varname sccloud in the subwdl.
			#output:
			#	Array[File] output_scp_files
		}
		call scp_outputs {
			input:
				input_csv_file=input_csv_file,
				preemptible=preemptible,
				alexandria_version=alexandria_version,
				scCloud_output_directory_stripped=scCloud_output_directory_stripped,
				scCloud_output_prefix=scCloud_output_prefix,
				output_scp_files=scCloud.output_scp_files,
				cluster_file=scCloud_output_directory_stripped+'/'+scCloud_output_prefix+".scp.X_fitsne.coords.txt"
			#output:
			##	File pca_coords
			##	File fitnse_coords
			##	File dense_matrix
			#	File alexandria_metadata
		}
	}
	output {
		File? alexandria_metadata = scp_outputs.alexandria_metadata
		File? pca_coords = scCloud_output_directory_stripped+'/'+scCloud_output_prefix+".scp.X_diffmap_pca.coords.txt"
		File? fitsne_coords = scCloud_output_directory_stripped+'/'+scCloud_output_prefix+".scp.X_fitsne.coords.txt"
		File? dense_matrix = scCloud_output_directory_stripped+'/'+scCloud_output_prefix+".scp.expr.txt"
	}
}

task setup_dropseq {
	String bucket_stripped
	Boolean run_dropseq
	Boolean is_bcl
	File input_csv_file
	String reference
	String dropseq_output_directory_stripped
	String dropseq_default_directory_stripped
	String alexandria_version
	Int preemptible

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

		mtm = pd.read_csv("/tmp/metadata_type_map.tsv", dtype=str, header=0, sep='\t')
		for col in csv.columns:
			if col == "Sample" or col == "R1_Path" or col == "BCL_Path" or col == "R2_Path": continue
			if not col in mtm["ATTRIBUTE"].tolist(): sys.exit("ERROR: Metadata \""+col+"\" is not a valid metadata type")

		# TODO: Address edge case of having more than one R1/R2/BCL_Path?

		dsl = pd.DataFrame()
		is_bcl=${true='True' false='False' is_bcl}
		if is_bcl:
			if not "BCL_Path" in csv.columns: sys.exit("ERROR: Missing required column \"BCL_Path\" for is_bcl=true.")
			dsl["BCL_Path"] = csv["BCL_Path"].apply(func=lambda path: "${bucket_stripped}/"+path).unique()

			def check_BCL(bcl_path, csv):
				try: sp.check_call(args=["gsutil", "ls", bcl_path], stdout=sp.DEVNULL)
				except sp.CalledProcessError: sys.exit("ERROR: "+bcl_path+" was not found.")
				samples = csv.loc[csv.BCL_Path == bcl_path.replace("${bucket_stripped}/", ''), "Sample"]
				if len(samples) is 0: sys.exit("ERROR: BCL path \""+bcl_path.replace("${bucket_stripped}/", '')+"\" in input_csv_file does not match any samples listed in input_csv_file.")
				def check_sample(sample, bcl_path):
					sample_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
					try: sample_sheet = sp.check_output(args=["gsutil", "cat", sample_sheet_path]).strip().decode()
					except sp.CalledProcessError: sys.exit("ERROR: Checked path \""+sample_sheet_path+"\", was not found.")
					with open("sample_sheet.csv", 'w') as ss:
						ss.write(sample_sheet.split("[Data]")[-1]) # Trims sample sheet...
					ss = pd.read_csv("sample_sheet.csv", dtype=str, header=1) # ...to everything below "[Data]"
					if not ss.Sample_Name.str.contains(sample, regex=False).any(): 
						sys.exit("ERROR: Sample \""+sample+"\" in input_csv_file does not match any samples listed in "+sample_sheet_path)
				samples.apply(func=check_sample, args=(bcl_path,))
				return bcl_path.strip('/').split('/')[-1] # Return basename of bcl_path, which is the sample name.

			dsl["BCL_Path"].apply(func=check_BCL, args=(csv,))
		else:
			dsl["Sample"] = csv["Sample"]
			#TODO: consider adding confirmation message, "Will be overriding from R1_Path and R2_Path"
			location_override = False
			if "R1_Path" in csv.columns and "R2_Path" in csv.columns: location_override = True
			else: csv["R1_Path"] = csv["R2_Path"] = csv["Sample"].replace(csv["Sample"], np.nan)
			
			def get_fastq_location(sample, csv, location_override, read):
				path = csv.loc[csv.Sample == sample, read+"_Path"].to_string(index=False).strip()
				if location_override is False or path == "NaN":
					fastq_path = "${dropseq_default_directory_stripped}/"+sample+'*'+read+"*.fastq.gz"
				else: fastq_path = "${bucket_stripped}/"+path
				try: path = sp.check_output(args=["gsutil", "ls", fastq_path]).strip().decode()
				except sp.CalledProcessError: sys.exit("ERROR: Checked path \""+fastq_path+"\", was not found.")
				return path

			dsl["R1_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(csv, location_override, "R1"))
			dsl["R2_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(csv, location_override, "R2"))
		dsl.to_csv("dropseq_locations.tsv", sep='\t', header=None, index=False)

		CODE

		gsutil -q -m cp dropseq_locations.tsv ${dropseq_output_directory_stripped}/
	}
	output {
		File dropseq_locations = "dropseq_locations.tsv"
	}
	runtime {
		docker: "shaleklab/alexandria:${alexandria_version}"
		preemptible: "${preemptible}"
	}
}

#DUMMY TASK for testing
task ds_dummy {
	File input_csv_file #.csv is a misnomer, actually a .tsv
	Boolean run_bcl2fastq
	String output_directory
	String reference
	String drop_seq_tools_version
	Int preemptible
	String zones

	command {
		echo "Run ds_dummy"
	}
	output {
		#Array[String] dge = ["${output_directory}/B0_2/B0_2_dge.txt"]
		#Array[String] sample_IDs = ["B0_2"]
		Array[String] dge = ["${output_directory}/190712_non2/190712_non2_dge.txt.gz", "${output_directory}/3July19PB/3July19PB_dge.txt.gz", "${output_directory}/3July19BM/3July19BM_dge.txt.gz"]
		Array[String] sample_IDs = ["190712_non2", "3July19PB", "3July19BM"]
	}
	runtime {
		docker: "regevlab/dropseq-${drop_seq_tools_version}" # Only tag is latest for 2.3.0
		preemptible: "${preemptible}"
	}
}

task setup_scCloud {
	Array[String?]? dges
	Array[String?]? sample_IDs
	Boolean run_dropseq # If false then do general setup
	File input_csv_file
	String reference
	String bucket_stripped
	String alexandria_version
	String dropseq_output_directory_stripped
	String scCloud_output_directory_stripped
	Int preemptible
	
	command <<<
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import sys
		import pandas as pd
		import numpy as np
		import subprocess as sp

		csv = pd.read_csv("${input_csv_file}", dtype=str, header=0)
		run_dropseq=${true='True' false='False' run_dropseq}		
	
		if run_dropseq is False:
			try: sp.check_call(args=["gsutil", "ls", "${bucket_stripped}"], stdout=sp.DEVNULL)
			except sp.CalledProcessError: sys.exit("ERROR: Bucket \"${bucket_stripped}\" was not found.")
			
			#TODO: Support hg38 and custom json reference files.
			valid_references=["hg19", "mm10", "hg19_mm10", "mmul_8.0.1"]
			if "${reference}" not in valid_references:
				sys.exit("ERROR: ${reference} does not match a valid reference: (\"hg19\", \"mm10\", \"hg19_mm10\", and \"mmul_8.0.1\").")
			
			for col in csv.columns: csv[col] = csv[col].str.strip()
			if "Sample" not in csv.columns: sys.exit("ERROR: Required column 'Sample' was not found in ${input_csv_file}.")
			csv = csv.dropna(subset=['Sample'])

			mtm = pd.read_csv("/tmp/metadata_type_map.tsv", dtype=str, header=0, sep='\t')
			for col in csv.columns:
				if col == "Sample" or col == "R1_Path" or col == "BCL_Path" or col == "R2_Path": continue
				if not col in mtm["ATTRIBUTE"].tolist(): sys.exit("ERROR: Metadata \""+col+"\" is not a valid metadata type")

		cm = pd.DataFrame()
		cm["Sample"] = csv["Sample"]
		def get_dge_location(sample, run_dropseq):
			location = "${dropseq_output_directory_stripped}/"+sample+'/'+sample+"_dge.txt.gz"
			try: sp.check_call(args=["gsutil", "ls", location], stdout=sp.DEVNULL)
			except sp.CalledProcessError: sys.exit("ERROR: "+location+" was not found.")
			return location
		cm["Location"] = csv["Sample"].apply(func=get_dge_location, args=(run_dropseq,))	
		cm.to_csv("count_matrix.csv", header=True, index=False)
		CODE
		
		gsutil -q -m cp count_matrix.csv ${scCloud_output_directory_stripped}/
	>>>
	output {
		#File count_matrix = if "${count_matrix_override}" != '' then "${count_matrix_override}" else "count_matrix.csv"
		File count_matrix = "count_matrix.csv"
	}
	runtime {
		docker: "shaleklab/alexandria:${alexandria_version}"
		preemptible: "${preemptible}"
	}
}

#DUMMY TASK for testing
task sc_dummy {
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
	Int preemptible
	String zones

	command {
		echo "Run sc_dummy"
	}
	output {
		Array[String] output_scp_files = ["${output_name}.scp.expr.txt", "${output_name}.scp.metadata.txt", "${output_name}.scp.X_diffmap_pca.coords.txt", "${output_name}.scp.X_fitsne.coords.txt"]
	}
	runtime {
		docker: "regevlab/sccloud-${sccloud_version}"
		preemptible: "${preemptible}"
	}
}

task scp_outputs {
	File input_csv_file
	String alexandria_version
	String scCloud_output_directory_stripped
	Array[File] output_scp_files
	Int preemptible
	File cluster_file
	String scCloud_output_prefix

	command {
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import pandas as pd

		amd = pd.read_csv("${cluster_file}", dtype=str, sep='\t', header=0)
		amd = amd.drop(columns=['X','Y'])
		def get_sample(element):
			if element == "TYPE": return "group"
			else: return '-'.join(element.split('-')[:-1])
		amd.insert(1, "Channel", pd.Series(amd["NAME"].map(get_sample)))

		csv = pd.read_csv("${input_csv_file}", dtype=str, header=0).dropna(subset=['Sample'])
		mtm = pd.read_csv("/tmp/metadata_type_map.tsv", dtype=str, header=0, sep='\t')
		if "R1_Path" in csv.columns and "R2_Path" in csv.columns: csv = csv.drop(columns=["R1_Path", "R2_Path"])
		if "BCL_Path" in csv.columns: csv = csv.drop(columns=["BCL_Path"])
		def get_metadata(element, csv, metadata, mtm):
			# TODO: Support outside metadata? Type cast data to validate that numeric is int/float, group is whatever.
			if element == "group": return mtm.loc[mtm.ATTRIBUTE == metadata, "TYPE"].to_string(index=False).strip() #For TYPE row, search for type in map
			else: return csv.loc[csv.Sample == element, metadata].to_string(index=False).strip()
		for metadata in csv.columns:
			if metadata == "Sample": continue
			amd[metadata] = amd["Channel"].apply(func=get_metadata, args=(csv, metadata, mtm))
			amd.to_csv("alexandria_metadata.txt", sep='\t', index=False)
		CODE
		
		gsutil -q -m cp alexandria_metadata.txt ${scCloud_output_directory_stripped}/
	}
	output {
		File alexandria_metadata = "alexandria_metadata.txt"
	}
	runtime {
		docker: "shaleklab/alexandria:${alexandria_version}"
		preemptible: "${preemptible}"
	}
}
