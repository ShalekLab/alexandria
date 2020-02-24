import subprocess as sp
import pandas as pd

class Tool(object):

	def __init__(self, name, entry, R1_path=None, R2_path=None, plate=None, BCL=None, SS_path=None):
		self.name = name
		self.entry = entry
		self.R1_path = R1_path
		self.R2_path = R2_path
		self.BCL_path = BCL_path
		self.SS_path = SS_path

	#######################################################################################################################################
	#														COMMON INPUTS/OUTPUTS
	#######################################################################################################################################

	@classmethod
	def get_tool(cls, name):
		if name == "dropseq":
			return Dropseq()
		elif name == "smartseq2":
			return Smartseq2()
		elif name == "kallisto-bustools":
			return Kallisto_Bustools()
		else:
			raise Exception("ALEXANDRIA: ERROR! Tool "+name+" must be one of the valid options: (dropseq, smartseq2)")

	@classmethod
	def check_bucket(cls, bucket):
		print("Checking bucket", bucket+"...")
		try: 
			sp.check_call(args=["gsutil", "ls", bucket], stdout=sp.DEVNULL)
		except sp.CalledProcessError:
			raise Exception("ALEXANDRIA: Bucket "+bucket+" was not found.")
	
	def check_reference(self, reference):
		valid_references=["hg19", "mm10", "hg19_mm10", "mmul_8.0.1", "GRCh38"]
		if reference not in valid_references:
			print("ALEXANDRIA: WARNING!", reference, "does not match a valid reference: (hg19, GRCh38, mm10, hg19_mm10, and mmul_8.0.1).")
			print("Inferring", reference, "as a path to a custom reference.")
		else: 
			print("Passing reference", reference)

	def check_metadata_headers(self, csv, metadata_type_map):
		mtm = pd.read_csv(metadata_type_map, dtype=str, header=0, sep='\t')
		ignore_columns = [self.entry, self.plate, self.R1_path, self.BCL_path, self.R2_path, self.SS_path]
		ignore_columns = filter(None, ignore_columns)
		metadata_headers = mtm["ATTRIBUTE"].tolist()
		print("Checking headers of all metadata columns.")
		for col in csv.drop(columns=ignore_columns, errors="ignore").columns:
			if not col in metadata_headers: # TODO: Warn user? but allow extraneous metadata.
				raise Exception("ALEXANDRIA: ERROR! Metadata "+col+" is not a valid metadata type")

	def transform_csv_file(self, input_csv_file):
		csv = pd.read_csv(input_csv_file, dtype=str, header=0)
		for col in csv.columns:
			csv[col] = csv[col].str.strip()
		return csv

	def write_locations(self, tls):
		tls.to_csv(self.name+"_locations.tsv", sep='\t', header=None, index=False)

	#######################################################################################################################################
	#															BCLs
	#######################################################################################################################################

	@classmethod
	def check_sequencing_run_path(cls, bcl_path, bucket_slash):
		print("ALEXANDRIA: For BCL_Path entry", bcl_path)
		if bcl_path.startswith("gs://") is False:
			bcl_path = bucket_slash + bcl_path
			print("Prepended the bucket to the entry;", bcl_path)
		print("Checking existence of sequencing run directory:", bcl_path)
		try: 
			sp.check_call(args=["gsutil", "ls", bcl_path], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! Sequencing run directory at "+bcl_path+" was not found.")
		print("FOUND", bcl_path)
		print("--------------------------")
		return bcl_path.strip('/')+'/'

	def get_sample_sheet_path(self, bcl_path, csv, bucket_slash):
		if self.SS_path in csv.columns: # If user supplied a column with potential overwrite paths to sample sheet.
			sample_sheet_path = str(csv.loc[ csv[self.BCL_path] == bcl_path, self.SS_path].iloc[0])
			if sample_sheet_path == "nan":
				sample_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
			elif sample_sheet_path.startswith("gs://") is False:
				sample_sheet_path = bucket_slash + sample_sheet_path #Prepend bucket if not a gsURI
		else:
			sample_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
		return sample_sheet_path

	@classmethod
	def get_trimmed_sample_sheet(cls, sample_sheet_path):
		try: 
			sample_sheet = sp.check_output(args=["gsutil", "cat", sample_sheet_path]).strip().decode()
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! Checked path "+sample_sheet_path+", sample sheet was not found in "+bcl_path)
		print("FOUND", sample_sheet_path)
		with open("trimmed_sample_sheet.csv", 'w') as ss:
			ss.write(sample_sheet.split("[Data]")[-1]) # Trims sample sheet...
		ss = pd.read_csv("trimmed_sample_sheet.csv", dtype=str, header=1) # ...to everything below "[Data]"
		if "Sample_Name" not in ss.columns:
			raise Exception("ALEXANDRIA: ERROR! Column Sample_Name was not found in the trimmed sample sheet of "+sample_sheet_path)
		return ss

	def get_entries(self, bcl_path, csv, sample_sheet_path):
		entries = csv.loc[ csv[self.BCL_path] == bcl_path, self.entry]
		if len(entries) is not 0: 
			return entries
		else:
			raise Exception("ALEXANDRIA: ERROR! Checked input_csv_file "+bcl_path+" no samples were found in"+sample_sheet_path)

	@classmethod
	def check_entry(cls, entry, ss):
		print("Checking if", entry, "exists in sample_sheet")
		if not ss.Sample_Name.str.contains(entry, regex=False).any(): # Check if Sample_Name column contains the sample.
			raise Exception("ALEXANDRIA: ERROR! entry "+entry+" in input_csv_file does not match any samples listed in the sample sheet")
		print("FOUND", entry)

	# Essentially main
	def get_validated_sample_sheet(self, bcl_path, csv, bucket_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out

		print("ALEXANDRIA: Finding sequencing run sample sheet for", bcl_path)
		sample_sheet_path = self.get_sample_sheet_path(bcl_path, csv, bucket_slash)

		print("Searching for sample sheet:", sample_sheet_path)
		ss = Tool.get_trimmed_sample_sheet(sample_sheet_path)

		print("Finding and checking samples listed in input_csv_file")
		entries = self.get_entries(bcl_path, csv, sample_sheet_path)
		
		entries.apply(func=Tool.check_entry, args=(ss,))
		
		print("--------------------------")
		return sample_sheet_path

	#######################################################################################################################################
	#															FASTQs
	#######################################################################################################################################

	def determine_location_override(self, csv):
		location_override = False
		if self.R1_path in csv.columns and self.R2_path in csv.columns:
			location_override = True
			print("Found R1 and R2 paths columns in input_csv_file, will override and search for paths from those columns.")
		return location_override

	@classmethod
	def construct_default_path(cls, bucket_slash, fastq_directory_slash, entry, read):
		if fastq_directory_slash.startswith("gs://"): 
			return fastq_directory_slash+entry+'_'+read+"*.fastq*" # TODO: Does SS2 allow uncompressed fastqs?
		else: 
			return bucket_slash+fastq_directory_slash+entry+'_'+read+"*.fastq*"

	@classmethod
	def determine_fastq_path(cls, entry, read, location_override, default_path, bucket_slash, entered_path):
		if location_override is False or entered_path == "NaN":
			print("For", entry, "read", read+":\nPath was not entered in input_csv_file, checking the constructed default path:\n" + default_path)
			return default_path
		elif entered_path.startswith("gs://"):
			print("For", entry, "read", read+":\nChecking entered path that begins with gsURI, checking:\n" + entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			print("For", entry, "read", read+":\nChecking entered path:\n" + bucket_slash + entered_path)
			return bucket_slash + entered_path

	@classmethod
	def validate_fastq_path(cls, fastq_path, default_path):
		# First Check the fastq_path, then if it fails then check the default directory.
		try:
			fastq_path = sp.check_output(args=["gsutil", "ls", fastq_path]).strip().decode()
		except sp.CalledProcessError: 
			print("ALEXANDRIA: WARNING! The file was not found at:\n" + fastq_path+ "\nChecking the fastq_directory variable...")
			try: 
				fastq_path = sp.check_output(args=["gsutil", "ls", default_path]).strip().decode() # Tries again but for default path
			except sp.CalledProcessError: 
				raise Exception("ALEXANDRIA: ERROR! Checked path "+fastq_path+", the fastq(.gz) was not found!")
		print("FOUND", fastq_path)
		print("--------------------------")
		return fastq_path

	def read_entered_path(self, csv, entry, read):
		if read in self.R1_path:
			fastq_column = self.R1_path
		elif read in self.R2_path:
			fastq_column = self.R2_path
		else:
			raise Exception("ALEXANDRIA DEV: Read was not found in either R1_path or R2_path.")
		# In row of entry, locate the fastq path
		fastq_path = csv.loc[ csv[self.entry] == entry, fastq_column]
		return fastq_path.to_string(index=False).strip()
	
	# Essentially main
	def get_validated_fastq_path(self, entry, read, csv, location_override, bucket_slash, fastq_directory_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		entered_path = self.read_entered_path(csv, entry, read)
		default_path = Tool.construct_default_path(bucket_slash, fastq_directory_slash, entry, read)
		fastq_path = Tool.determine_fastq_path(entry, read, location_override, default_path, bucket_slash, entered_path)
		validated_fastq_path = Tool.validate_fastq_path(fastq_path, default_path)
		return validated_fastq_path

	#######################################################################################################################################
	#														CUMULUS SETUP
	#######################################################################################################################################

	def get_dge_location(self, entry, bucket_slash, output_directory_slash):
		location = bucket_slash + output_directory_slash + entry + '/' + entry + "_dge.txt.gz"
		print("Searching for count matrix at", location)
		try:
			sp.check_call(args=["gsutil", "ls", location], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! "+location+" was not found. Ensure that the path is correct and that the count matrix is in <name>_dge.txt.gz format!")
		print("FOUND", location)
		print("--------------------------")
		return location

	def generate_sample_sheet(self, csv, bucket_slash, output_directory_slash, reference):
		cm = pd.DataFrame()
		cm[self.entry] = csv[self.entry]
		cm["Location"] = csv[self.entry].apply(func=get_dge_location, args=(bucket_slash, output_directory_slash))
		print("Location column added successfully.")
		cm.insert(1, "Reference", pd.Series(cm[self.entry].map(lambda x: reference)))
		print("Reference column added successfully.")
		return cm

	#######################################################################################################################################
	#														SCP OUTPUTS
	#######################################################################################################################################

	@classmethod
	def serialize_scp_outputs(cls, scp_outputs_list, names):
		with open (scp_outputs_list, 'r') as scp_outputs:
			for name in names:
				is_found = False
				for path in scp_outputs:
					path = path.strip('\n')
					if path.endswith("X_fitsne.coords.txt"): # Find cluster file
						cluster_file = path
					if path.endswith(name): # Serialize whatever file path
						open(name, 'w').write(path)
						is_found = True
						break
				if is_found is False:
					raise Exception("Path to "+name+" file was not found.")
		return cluster_file

	@classmethod
	def transform_cluster_file(cls, cluster_file):
		amd = pd.read_csv(cluster_file, dtype=str, sep='\t', header=0)
		amd = amd.drop(columns=['X','Y'])
		def get_entry(entry):
			if entry == "TYPE":
				return "group"
			else:
				return '-'.join(entry.split('-')[:-1]) # Get everything before the first hyphen
		amd.insert(1, "Channel", pd.Series(amd["NAME"].map(get_entry)))
		return amd

	def isolate_metadata_columns(self, input_csv_file):
		csv = pd.read_csv(input_csv_file, dtype=str, header=0)
		#csv = csv.dropna(subset=['Sample'])
		drop_columns = [self.plate, self.R1_path, self.BCL_path, self.R2_path, self.SS_path]
		drop_columns = filter(None, ignore_columns)
		csv = csv.drop(columns=drop_columns, errors="ignore")
		return csv

	def map_metadata(self, csv, amd, metadata_type_map):
		mtm = pd.read_csv(metadata_type_map, dtype=str, header=0, sep='\t') #TERRA
		def get_metadata(entry, csv, metadata, mtm):
			# TODO: Support outside metadata? Type cast data to validate that numeric is int/float, group is whatever.
			if entry == "group":
				return mtm.loc[mtm.ATTRIBUTE == metadata, "TYPE"].to_string(index=False).strip() # For TYPE row, search for type in map
			else:
				return csv.loc[ csv[self.entry] == entry, metadata].to_string(index=False).strip() # For all rows below, get the metadata at entry

		for metadata in csv.columns:
			if metadata == self.entry: continue
			amd[metadata] = amd["Channel"].apply(func=get_metadata, args=(csv, metadata, mtm))
		return amd

class Dropseq(Tool):
	def __init__(self):
		self.name = "dropseq"
		self.entry = "Sample"
		self.R1_path = "R1_Path"
		self.R2_path = "R2_Path"
		self.plate = None
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"

	def transform_csv_file(self, csv):
		csv = super().transform_csv_file(csv)
		errors=[]
		if self.entry not in csv.columns:
			errors.append("Please ensure your cell column is named '"+self.entry+"'.")
		if "R1_fastq" in csv.columns or "R2_fastq" in csv.columns:
			errors.append("Please rename both of your FASTQ path column headers to '"+self.R1_path+"'' and '"+self.R2_path+"'.")
		if len(errors) > 0:
			raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors))
		return csv #.dropna(subset=[self.entry]) 

	def write_locations(self, tls):
		tls.to_csv(self.name+"_locations.tsv", sep='\t', header=None, index=False)

class Smartseq2(Tool):
	def __init__(self):
		self.name = "smartseq2"
		self.entry = "Cell"
		self.R1_path = "Read1"
		self.R2_path = "Read2"
		self.plate = "Plate"
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"

	def transform_csv_file(self, csv):
		csv = super().transform_csv_file(csv)
		errors=[]
		if self.entry not in csv.columns:
			errors.append("Please ensure your cell column is named '"+self.entry+"'.")
		if self.plate not in csv.columns:
			errors.append("Please ensure your plate column is named '"+self.plate+"'.")
		if "R1_Path" in csv.columns or "R2_Path" in csv.columns:
			errors.append("Please rename both of your FASTQ path column headers to '"+self.R1_path+"' and '"+self.R2_path+"'.")
		if len(errors) > 0:
			raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors))
		return csv #.dropna(subset=[self.entry]) 

	def write_locations(self, tls):
		tls.to_csv(self.name+"_locations.tsv", header=True, index=False)

class Kallisto_Bustools(Tool):
	def __init__(self):
		self.name = "kallisto-bustools"
		self.entry = "Sample"
		self.R1_path = "R1_Paths"
		self.R2_path = "R1_Paths"
		self.plate = None
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"