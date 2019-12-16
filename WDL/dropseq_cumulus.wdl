# By jgatter [at] broadinstitute.org, created October 22nd, 2019
# https://portal.firecloud.org/?return=terra#methods/alexandria/dropseq_cumulus/
# Incorporates subworkflows made by jgould [at] broadinstitute.org and Regev Lab / Klarnan Cell Observatory
# ------------------------------------------------------------------------------------------------------------------------------------------

import "https://api.firecloud.org/ga4gh/v1/tools/cumulus:dropseq_workflow/versions/4/plain-WDL/descriptor" as dropseq #TERRA
import "https://api.firecloud.org/ga4gh/v1/tools/cumulus:cumulus/versions/7/plain-WDL/descriptor" as cumulus #TERRA

workflow dropseq_cumulus {
	
	# User-inputted .csv file that contains in whatever order:
	#	(REQUIRED) the 'Sample' column, 
	#	(OPTIONAL) both 'R1_Path' and 'R2_Path' columns
	#	(OPTIONAL) 'BCL_Path' column
	#	(OPTIONAL) other metadata columns that currently aren't used/outputted by the workflow
	File input_csv_file
	#File metadata_type_map #LOCAL

	#The file name assigned to the cumulus outputs.
	String cumulus_output_prefix = "sco"

	# Output object, seems to be a path/to/dir in the bucket.
	# TODO: Test if can point to non-workspace buckets.
	# TODO! Make every task in the file work for empty strings. Probably should keep below lines but append +'/' after the sub().
	String bucket
	String bucket_slash = sub(bucket, "/+$", '')+'/'
	String dropseq_output_directory #=''
	String dropseq_output_directory_slash = if dropseq_output_directory == '' then '' else sub(dropseq_output_directory, "/+$", '')+'/'
	String cumulus_output_directory
	String cumulus_output_directory_slash = if cumulus_output_directory == '' then '' else sub(cumulus_output_directory, "/+$", '')+'/'
	String dropseq_default_directory
	String dropseq_default_directory_slash = if dropseq_default_directory == '' then '' else sub(dropseq_default_directory, "/+$", '')+'/'

	# "hg19" or another reference.
	String reference

	# At least one of the following Booleans must be set as true
	# Set true to run alignment by dropseq pipeline
	Boolean run_dropseq
	# To use bcl2fastq you MUST locally docker login to your broadinstitute.org-affiliated docker account.
	Boolean is_bcl #= false
	# Set true to run clustering/visualization by cumulus
	Boolean run_cumulus

	# Version numbers to select the repo-specific, tagged dockerfile at runtime.
	String dropseq_registry = "cumulusprod" # https://hub.docker.com/r/cumulusprod/dropseq/tags
	String dropseq_registry_stripped = sub(dropseq_registry, "/+$", '')
	String dropseq_tools_version = "2.3.0"
	String cumulus_version = "0.8.0:v1.0"
	String? cumulus_registry = "cumulusprod" # https://hub.docker.com/r/cumulusprod/cumulus/tags
	String? cumulus_registry_stripped = sub(cumulus_registry, "/+$", '')
	String? cumulus_version = "0.10.0"
	String alexandria_registry = "shaleklab"
	String alexandria_registry_stripped = sub(alexandria_registry, "/+$", '')
	String alexandria_version = "0.1"
	Int? preemptible = 2
	String? zones = "us-east1-d us-west1-a us-west1-b"

	if (run_dropseq) {
		call setup_dropseq { # Check user inputs .csv and create dropseq_locations.tsv for dropseq and/or count_matrix.csv for cumulus
			input:
				bucket_slash=bucket_slash,
				run_dropseq=run_dropseq,
				is_bcl=is_bcl,
				input_csv_file=input_csv_file,
				reference=reference,
				dropseq_output_directory_slash=dropseq_output_directory_slash,
				dropseq_default_directory_slash=dropseq_default_directory_slash,
				preemptible=preemptible,
				#metadata_type_map=metadata_type_map, #LOCAL
				alexandria_registry=alexandria_registry_stripped,
				alexandria_version=alexandria_version
		}
		call dropseq.dropseq_workflow as dropseq {
		#call ds_dummy as dropseq {
			input:
				input_csv_file=setup_dropseq.dropseq_locations, #.csv is a misnomer, actually a .tsv
				run_bcl2fastq=is_bcl,
				output_directory=bucket_slash + sub(dropseq_output_directory_slash, "/+$", ''),
				reference=reference,
				zones=zones,
				preemptible=preemptible,
				docker_registry=dropseq_registry_stripped,
				drop_seq_tools_version=dropseq_tools_version # Varname drop_seq_tools_version in the subwdl.
		}
	}

	if (run_cumulus) {
		call setup_cumulus{
			input: 
				dges=dropseq.dge,
				run_dropseq=run_dropseq,
				input_csv_file=input_csv_file,
				reference=reference,
				alexandria_version=alexandria_version,
				preemptible=preemptible,
				bucket_slash=bucket_slash,
				dropseq_output_directory_slash=dropseq_output_directory_slash,
				#metadata_type_map=metadata_type_map, #LOCAL
				alexandria_registry=alexandria_registry_stripped,
				cumulus_output_directory_slash=cumulus_output_directory_slash,
		}
		call cumulus.cumulus as cumulus {
		#call cumulus_dummy as cumulus {
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
				alexandria_registry=alexandria_registry_stripped,
				alexandria_version=alexandria_version,
				cumulus_output_directory_slash=cumulus_output_directory_slash,
				cumulus_output_prefix=cumulus_output_prefix,
				#metadata_type_map=metadata_type_map, #LOCAL
				#cluster_file="bucket/bcl_cumulus/"+cumulus_output_prefix+".scp.X_fitsne.coords.txt", #LOCAL
				cluster_file=bucket_slash+cumulus_output_directory_slash+cumulus_output_prefix+".scp.X_fitsne.coords.txt",
				output_scp_files=cumulus.output_scp_files
		}
	}
	output {
		File? alexandria_metadata = scp_outputs.alexandria_metadata
		File? pca_coords = cumulus_output_directory_slash+cumulus_output_prefix+".scp.X_diffmap_pca.coords.txt"
		File? fitsne_coords = cumulus_output_directory_slash+cumulus_output_prefix+".scp.X_fitsne.coords.txt"
		File? dense_matrix = cumulus_output_directory_slash+cumulus_output_prefix+".scp.expr.txt"
		#File? pca_coords = "bucket/bcl_cumulus"+'/'+cumulus_output_prefix+".scp.X_diffmap_pca.coords.txt" #LOCAL
		#File? fitsne_coords = "bucket/bcl_cumulus"+'/'+cumulus_output_prefix+".scp.X_fitsne.coords.txt" #LOCAL
		#File? dense_matrix = "bucket/bcl_cumulus"+'/'+cumulus_output_prefix+".scp.expr.txt" #LOCAL
	}
}

task setup_dropseq {
	String bucket_slash
	Boolean run_dropseq
	Boolean is_bcl
	File input_csv_file
	String reference
	String dropseq_output_directory_slash
	String dropseq_default_directory_slash
	String alexandria_registry
	String alexandria_version
	Int preemptible
	#File metadata_type_map #LOCAL

	command {
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import sys
		import pandas as pd
		import numpy as np
		import subprocess as sp

		bucket_slash="${bucket_slash}"
		reference="${reference}"
		dropseq_default_directory_slash="${dropseq_default_directory_slash}"
		is_bcl=${true='True' false='False' is_bcl}
		input_csv_file="${input_csv_file}"

		print("ALEXANDRIA: Running setup for Drop-Seq workflow")
		print("Checking bucket", bucket_slash)
		try: sp.check_call(args=["gsutil", "ls", bucket_slash], stdout=sp.DEVNULL)
		except sp.CalledProcessError: sys.exit("ALEXANDRIA ERROR: Bucket "+bucket_slash+" was not found.")
			
		#TODO: Support custom json reference files.
		valid_references=["hg19", "mm10", "hg19_mm10", "mmul_8.0.1", "GRCh38"]
		if reference not in valid_references:
			print("ALEXANDRIA WARNING: "+reference+" does not match a valid reference: (hg19, GRCh38, mm10, hg19_mm10, and mmul_8.0.1).")
			print("Inferring "+reference+" as a path to a custom reference.")
		else: print("Passing reference", reference)

		csv = pd.read_csv(input_csv_file, dtype=str, header=0)
		pd.options.display.max_colwidth = 2048 # To ensure the full string is written to file.
		for col in csv.columns: csv[col] = csv[col].str.strip()
		if "Sample" not in csv.columns: sys.exit("ALEXANDRIA ERROR: Required column 'Sample' was not found in "+input_csv_file)
		csv = csv.dropna(subset=['Sample'])

		print("Checking headers of all metadata columns.")
		#$mtm = pd.read_csv("metadata_type_map", dtype=str, header=0, sep='\t') #LOCAL
		mtm = pd.read_csv("/tmp/metadata_type_map.tsv", dtype=str, header=0, sep='\t') #TERRA
		for col in csv.columns:
			if col == "Sample" or col == "R1_Path" or col == "BCL_Path" or col == "R2_Path" or col == "SS_Path": continue
			if not col in mtm["ATTRIBUTE"].tolist(): sys.exit("ALEXANDRIA ERROR: Metadata column header "+col+" is not a valid metadata type")

		# TODO: Address edge case of having more than one R1/R2/BCL_Path column?
		dsl = pd.DataFrame() # The dataframe that becomes dropseq_locations.tsv, the input sample sheet of dropseq_workflow.
		if is_bcl:
			print("is_bcl is set to true, will be checking 'BCL_Path' and 'Sample' columns as well as optional 'SS_Path' column.")
			if not "BCL_Path" in csv.columns: sys.exit("ALEXANDRIA ERROR: Missing required column 'BCL_Path'")	
			print("--------------------------")

			def get_sample_sheet(bcl_path):
				print("ALEXANDRIA: Finding sequencing run sample sheet for ", bcl_path)
				if "SS_Path" in csv.columns: # If user supplied a column with potential overwrite paths to sample sheet.
					sample_sheet_path = str(csv.loc[csv.BCL_Path == bcl_path, "SS_Path"].iloc[0])
					if sample_sheet_path == "nan":
						sample_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
					elif sample_sheet_path.startswith("gs://") is False:
						sample_sheet_path = bucket_slash + sample_sheet_path #Prepend bucket if not a gsURI
				else: sample_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"

				print("Searching path:", sample_sheet_path)
				try: sample_sheet = sp.check_output(args=["gsutil", "cat", sample_sheet_path]).strip().decode()
				except sp.CalledProcessError: sys.exit("ALEXANDRIA ERROR: Checked path "+sample_sheet_path+", sample sheet was not found in "+bcl_path)
				print("FOUND", sample_sheet_path)
				with open("sample_sheet.csv", 'w') as ss:
					ss.write(sample_sheet.split("[Data]")[-1]) # Trims sample sheet...
				ss = pd.read_csv("sample_sheet.csv", dtype=str, header=1) # ...to everything below "[Data]"

				print("Finding samples listed in input_csv_file", sample_sheet_path)
				samples = csv.loc[csv.BCL_Path == bcl_path, "Sample"]
				if len(samples) is 0: sys.exit("ALEXANDRIA ERROR: Checked input_csv_file "+bcl_path+" no samples were found in"+sample_sheet_path)
				samples.apply(func=check_sample, args=(ss,))
				print("--------------------------")
				return sample_sheet_path
			
			def check_sample(sample, ss):
				print("Checking if", sample, "exists in sample_sheet")
				if not ss.Sample_Name.str.contains(sample, regex=False).any(): # Check if Sample_Name column contains the sample.
					sys.exit("ALEXANDRIA ERROR: Sample "+sample+" in input_csv_file does not match any samples listed in the sample sheet")
				print("FOUND", sample)

			def check_BCL(bcl_path):
				print("ALEXANDRIA: For BCL_Path entry", bcl_path)
				if bcl_path.startswith("gs://") is False:
					bcl_path = bucket_slash + bcl_path
					print("Prepended the bucket to the entry:", bcl_path)
				print("Checking existence of sequencing run directory:", bcl_path)
				try: sp.check_call(args=["gsutil", "ls", bcl_path], stdout=sp.DEVNULL)
				except sp.CalledProcessError: sys.exit("ALEXANDRIA ERROR: Sequencing run directory at "+bcl_path+" was not found.")
				print("FOUND", bcl_path)
				print("--------------------------")
				return bcl_path.strip('/')+'/'
			
			csv["BCL_Path"] = csv["BCL_Path"].apply(func=check_BCL)
			dsl["BCL_Path"] = csv["BCL_Path"].unique()
			dsl["SS_Path"] = dsl["BCL_Path"].apply(func=get_sample_sheet)

		else: # Generate a list of FASTQs
			print("is_bcl is set to false, will be checking 'Sample' column as well as optional 'R1_Path' and 'R2_Path' columns.")
			dsl["Sample"] = csv["Sample"]
			location_override = False
			if "R1_Path" in csv.columns and "R2_Path" in csv.columns:
				location_override = True
				print("Found R1_Path and R2_Path columns in"+input_csv_file+", will override and search for paths from those columns.")
			else: 
				print("No R1_Path and R2_Path columns found, will be checking default constructed paths for fastq(.gz) files.")
				csv["R1_Path"] = csv["R2_Path"] = csv["Sample"].replace(csv["Sample"], np.nan)
			print("--------------------------")

			def get_fastq_location(sample, location_override, read):
				cell = csv.loc[csv.Sample == sample, read+"_Path"].to_string(index=False).strip()
				if len(cell) > 2048: sys.exit("ALEXANDRIA ERROR: For "+sample+' '+read+", the path "+path+" exceeds maximum length of 2048 characters.")
				if dropseq_default_directory_slash.startswith("gs://"): default_path = dropseq_default_directory_slash+sample+'*'+read+"*.fastq*"
				else: default_path = bucket_slash+dropseq_default_directory_slash+sample+'*'+read+"*.fastq*"
				if location_override is False or cell == "NaN":
					fastq_path = default_path
					print("For", sample, read+":\nPath was not entered in ", input_csv_file, ", checking default constructed path:\n" + fastq_path)
				elif cell.startswith("gs://"):
					fastq_path = cell
					print("For", sample, read+":\nChecking entered path that begins with gsURI, checking:\n" + fastq_path)
				else:
					fastq_path = bucket_slash+cell
					print("For", sample, read+":\nChecking entered path:\n" + fastq_path)
				try: fastq_path = sp.check_output(args=["gsutil", "ls", fastq_path]).strip().decode()
				except sp.CalledProcessError: 
					print("ALEXANDRIA WARNING: The file was not found at:\n" + fastq_path+ "\nChecking the dropseq_default_directory...")
					try: fastq_path = sp.check_output(args=["gsutil", "ls", default_path]).strip().decode() # Tries again but for default path
					except: sys.exit("ALEXANDRIA ERROR: Checked path "+fastq_path+", the fastq(.gz) was not found!")
				print("FOUND", fastq_path)
				print("--------------------------")
				return fastq_path

			dsl["R1_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(location_override, "R1"))
			dsl["R2_Path"] = csv["Sample"].apply(func=get_fastq_location, args=(location_override, "R2"))
		dsl.to_csv("dropseq_locations.tsv", sep='\t', header=None, index=False)
		print("ALEXANDRIA SUCCESS: Drop-Seq workflow setup is complete, proceeding to run the workflow.")
		CODE

		gsutil -q -m cp dropseq_locations.tsv ${bucket_slash}${dropseq_output_directory_slash}
	}
	output {
		File dropseq_locations = "dropseq_locations.tsv"
	}
	runtime {
		docker: "${alexandria_registry}/alexandria:${alexandria_version}"
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
		echo "Run dropseq_dummy"
	}
	output {
		Array[String] dge = if run_bcl2fastq == false then ["${output_directory}/B0_2/B0_2_dge.txt"] else ["${output_directory}/190712_non2/190712_non2_dge.txt.gz", "${output_directory}/3July19PB/3July19PB_dge.txt.gz", "${output_directory}/3July19BM/3July19BM_dge.txt.gz"]
	}
	runtime {
		docker: "${docker_registry}/dropseq:${drop_seq_tools_version}"
		preemptible: "${preemptible}"
	}
}

task setup_cumulus {
	Array[String?]? dges
	Boolean run_dropseq
	File input_csv_file
	String reference
	String bucket_slash
	String alexandria_registry_stripped
	String alexandria_version
	String dropseq_output_directory_slash
	String cumulus_output_directory_slash
	Int preemptible
	#File metadata_type_map #LOCAL
	
	command <<<
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import sys
		import pandas as pd
		import numpy as np
		import subprocess as sp

		input_csv_file="${input_csv_file}"
		run_dropseq=${true='True' false='False' run_dropseq}
		reference="${reference}"
		bucket_slash="${bucket_slash}"
		dropseq_default_directory_slash="${dropseq_default_directory_slash}"


		print("ALEXANDRIA: Running setup for Cumulus workflow")
		csv = pd.read_csv(input_csv_file, dtype=str, header=0)	
		if run_dropseq is True:
			print("Checking bucket", bucket_slash)
			try: sp.check_call(args=["gsutil", "ls", bucket_slash], stdout=sp.DEVNULL)
			except sp.CalledProcessError: sys.exit("ALEXANDRIA: Bucket "+bucket_slash+" was not found.")
			
			#TODO: Support MMUL_8_0_1?
			valid_references=["hg19", "mm10", "hg19_mm10", "mmul_8.0.1", "GRCh38"]
			if reference not in valid_references:
				print("ALEXANDRIA WARNING:", reference, "does not match a valid reference: (hg19, GRCh38, mm10, hg19_mm10, and mmul_8.0.1).")
				print("Inferring", reference, "as a path to a custom reference.")
			else: print("Passing reference", reference)

			for col in csv.columns: csv[col] = csv[col].str.strip()
			if "Sample" not in csv.columns: sys.exit("ALEXANDRIA ERROR: Required column 'Sample' was not found in "+input_csv_file)
			csv = csv.dropna(subset=['Sample'])

			#$mtm = pd.read_csv("metadata_type_map", dtype=str, header=0, sep='\t') #LOCAL
			mtm = pd.read_csv("/tmp/metadata_type_map.tsv", dtype=str, header=0, sep='\t') #TERRA
			for col in csv.columns:
				if col == "Sample" or col == "R1_Path" or col == "BCL_Path" or col == "R2_Path": continue
				if not col in mtm["ATTRIBUTE"].tolist(): sys.exit("ALEXANDRIA ERROR: Metadata "+col+" is not a valid metadata type")

		print("--------------------------")
		cm = pd.DataFrame()
		cm["Sample"] = csv["Sample"]
		#TODO: Check that dge's end in txt.gz and give error message if not
		def get_dge_location(sample):
			location = bucket_slash+dropseq_default_directory_slash+sample+'/'+sample+"_dge.txt.gz"
			print("Searching for count matrix at", location)
			try: sp.check_call(args=["gsutil", "ls", location], stdout=sp.DEVNULL)
			except sp.CalledProcessError: sys.exit("ALEXANDRIA ERROR: "+location+" was not found. Ensure the count matrix is in .txt.gz format!")
			print("FOUND", location)
			print("--------------------------")
			return location
		cm["Location"] = csv["Sample"].apply(func=get_dge_location)
		print("Location column added successfully.")
		cm.insert(1, "Reference", pd.Series(cm["Sample"].map(lambda x: reference)))
		print("Reference column added successfully.")
		cm.to_csv("count_matrix.csv", header=True, index=False) # Scope might need to change if count_matrix_override is supported.
		print("ALEXANDRIA SUCCESS: Cumulus workflow setup is complete, proceeding to run the workflow.")
		CODE
		
		gsutil -q -m cp count_matrix.csv ${bucket_slash}${cumulus_output_directory_slash}
	>>>
	output {
		File count_matrix = "count_matrix.csv"
	}
	runtime {
		docker: "${alexandria_registry_stripped}alexandria:${alexandria_version}"
		preemptible: "${preemptible}"
	}
}

#DUMMY TASK for testing
task cumulus_dummy {
	File input_file
	String output_name
	Boolean is_dropseq
	String genome
	Boolean generate_scp_outputs
	Boolean output_dense
	String cumulus_version
	String cumulus_docker_registry_stripped
	Int preemptible
	String zones

	command {
		echo "Run cumulus_dummy"
	}
	output {
		Array[String] output_scp_files = ["${output_name}.scp.expr.txt", "${output_name}.scp.metadata.txt", "${output_name}.scp.X_diffmap_pca.coords.txt", "${output_name}.scp.X_fitsne.coords.txt"]
	}
	runtime {
		docker: "cumul"
		preemptible: "${preemptible}"
	}
}

task scp_outputs {
	File input_csv_file
	String alexandria_registry_stripped
	String alexandria_version
	String cumulus_output_directory_slash
	Array[String] output_scp_files
	Int preemptible
	File cluster_file
	String cumulus_output_prefix
	String bucket_slash
	#File metadata_type_map #LOCAL

	command {
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import pandas as pd

		cluster_file="${cluster_file}"
		input_csv_file="${input_csv_file}"

		amd = pd.read_csv(cluster_file, dtype=str, sep='\t', header=0)
		amd = amd.drop(columns=['X','Y'])
		def get_sample(element):
			if element == "TYPE": return "group"
			else: return '-'.join(element.split('-')[:-1])
		amd.insert(1, "Channel", pd.Series(amd["NAME"].map(get_sample)))

		csv = pd.read_csv(input_csv_file, dtype=str, header=0).dropna(subset=['Sample'])
		#$mtm = pd.read_csv("metadata_type_map", dtype=str, header=0, sep='\t') #LOCAL
		mtm = pd.read_csv("/tmp/metadata_type_map.tsv", dtype=str, header=0, sep='\t') #TERRA
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
		print("ALEXANDRIA SUCCESS: Wrote alexandria_metadata.txt, finishing the dropseq_cumulus workflow.")
		CODE
		
		gsutil -q -m cp alexandria_metadata.txt ${bucket_slash}${cumulus_output_directory_slash}
	}
	output {
		File alexandria_metadata = "alexandria_metadata.txt"
	}
	runtime {
		docker: "${alexandria_registry_stripped}alexandria:${alexandria_version}"
		preemptible: "${preemptible}"
	}
}