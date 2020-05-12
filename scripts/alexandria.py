import subprocess as sp
import pandas as pd
import numpy as np
import os
import os.path as osp

class Alexandria(object):
	
	def __init__(self, dictionary): 
		self.__dict__ = dictionary
		if not "name" in dictionary.keys():
			raise Exception("ALEXANDRIA: ERROR! The Alexandria must have a name.")
		if not "sheet" in dictionary.keys():
			raise Exception("ALEXANDRIA: ERROR! The Alexandria must have a sample sheet.")
		if not "entry" in dictionary.keys():
			raise Exception("ALEXANDRIA: ERROR! The Alexandria must have a column header for entry identifiers.")
		self.sheet = self.make_dataframe(self.sheet)

	#############################################################################################################################
	#	COMMON INPUTS/OUTPUTS
	#############################################################################################################################

	@classmethod
	def get_tool(cls, name, sheet):
		from presets import Dropseq, Smartseq2, Kallisto_Bustools, Cellranger
		name = name.lower()
		if name == "dropseq":
			return Dropseq(sheet)
		elif name == "smartseq2":
			return Smartseq2(sheet)
		elif name.replace('-', '_') == "kallisto_bustools":
			return Kallisto_Bustools(sheet)
		elif name == "cellranger":
			return Cellranger(sheet)
		else:
			raise Exception("ALEXANDRIA: ERROR! Alexandria "+name+" must be one of the valid options: "
				"(Dropseq, Smartseq2, Kallisto_Bustools, Cellranger)")

	@classmethod
	def make_dataframe(cls, alexandria_sheet):
		if alexandria_sheet is None:
			return pd.DataFrame()
		if isinstance(alexandria_sheet, pd.core.frame.DataFrame):
			sheet = alexandria_sheet
		elif isinstance(alexandria_sheet, str):
			if not alexandria_sheet.endswith(".tsv"):
				print("ALEXANDRIA: WARNING! Ensure that the alexandria_sheet is a tab-delimited text file!")
			sheet = pd.read_csv(alexandria_sheet, dtype=str, header=0, sep='\t')
		else:
			raise Exception("ALEXANDRIA: ERROR! alexandria_sheet was neither a string nor a Pandas DataFrame!")		
		for col in sheet.columns:
			sheet[col] = sheet[col].str.strip()
		return sheet

	def check_dataframe(self):
		pass

	@classmethod
	def check_bucket(cls, bucket):
		print("Checking bucket", bucket+"...")
		try: 
			sp.check_call(args=["gsutil", "ls", bucket], stdout=sp.DEVNULL)
		except sp.CalledProcessError:
			raise Exception("ALEXANDRIA: ERROR! Bucket "+bucket+" was not found.")
	
	def check_custom_reference(self, reference):
		if not reference.beginswith("gs://"):
			raise Exception("ALEXANDRIA: ERROR! Custom reference "+reference+" must be on a "
				"Google bucket and entered as the full gsURI path!")
		try: 
			sp.check_call(args=["gsutil", "ls", reference], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! Custom reference at "+reference+" was not found.")

	def check_reference(self, reference):
		if self.custom_reference_extension is not None and reference.endswith(self.custom_reference_extension):
			self.check_custom_reference(reference) 
		elif reference not in self.provided_references:
			raise Exception("ALEXANDRIA: ERROR! "+reference+" does not match a provided reference "
				"("+ ", ".join(self.provided_references) +") or does not have a valid filename extension.") 
		print("Passing reference", reference)

	def check_aligner(self, aligner):
		if aligner is None or aligner in self.aligners:
			return
		else:
			raise Exception("ALEXANDRIA: ERROR! Aligner '"+aligner+"'' does not match a valid aligner "
				"(" + ", ".join(self.aligners) + ").")

	def check_metadata_headers(self, metadata_type_map):
		metadata_type_map = pd.read_csv(metadata_type_map, dtype=str, header=0, sep='\t')
		ignore_columns=[value for value in vars(self).values() if isinstance(value, str)]
		metadata_headers = metadata_type_map["attribute"].tolist()
		print("Checking headers of all metadata columns.")
		for col in self.sheet.drop(columns=ignore_columns, errors="ignore").columns:
			if not col in metadata_headers: # TODO: Warn user? but allow extraneous metadata.
				raise Exception("ALEXANDRIA: ERROR! Metadata "+col+" is not a valid metadata type.")

	def concatenate_sheets(self, sheets):
		for sheet in sheets:
			new_sheet = pd.read_csv(sheet, sep='\t', 
				usecols=[i for i in range(3)],
				names=[self.entry, self.R1_path, self.R2_path]
			)
			self.sheet = pd.concat(objs=[self.sheet, new_sheet], join="outer")

	def write_locations(self, tool_sheet):
		tool_sheet.to_csv(self.name+"_locations.tsv", sep='\t', header=None, index=False)

	#############################################################################################################################
	#	BCLs
	#############################################################################################################################

	def check_sequencing_run_path(self, bcl_path, bucket_slash):
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

	def get_bcl_sheet_path(self, bcl_path, bucket_slash):
		if self.SS_path in self.sheet.columns: # If user supplied a column with potential overwrite paths to sample sheet.
			bcl_sheet_path = str(self.sheet.loc[ self.sheet[self.BCL_path] == bcl_path, self.SS_path].iloc[0])
			if bcl_sheet_path == "nan":
				bcl_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
			elif bcl_sheet_path.startswith("gs://") is False:
				bcl_sheet_path = bucket_slash + bcl_sheet_path #Prepend bucket if not a gsURI
		else:
			bcl_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
		return bcl_sheet_path

	def get_trimmed_bcl_sheet(self, bcl_sheet_path):
		try: 
			bcl_sheet = sp.check_output(args=["gsutil", "cat", bcl_sheet_path]).strip().decode()
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! Checked for "+bcl_sheet+", sample sheet was not found in "+bcl_sheet_path)
		print("FOUND BCL directory sample sheet", bcl_sheet_path)
		with open("trimmed_bcl_sheet.csv", 'w') as ss:
			ss.write(bcl_sheet.split("[Data]")[-1]) # Trims sample sheet...
		ss = pd.read_csv("trimmed_bcl_sheet.csv", dtype=str, header=1) # ...to everything below "[Data]"
		if "Sample_Name" not in ss.columns:
			raise Exception("ALEXANDRIA: ERROR! Column Sample_Name was not found in the sample sheet of "+bcl_sheet_path)
		return ss

	def get_entries(self, bcl_path, bcl_sheet_path):
		entries = self.sheet.loc[ self.sheet[self.BCL_path] == bcl_path, self.entry]
		if len(entries) is not 0: 
			return entries
		else:
			raise Exception("ALEXANDRIA: ERROR! Checked alexandria_sheet "+bcl_path+" no samples were found in"+bcl_sheet_path)

	def check_entry(self, entry, ss):
		print("Checking if", entry, "exists in bcl_sheet")
		if not ss.Sample_Name.str.contains(entry, regex=False).any(): # Check if Sample_Name column contains the sample.
			raise Exception("ALEXANDRIA: ERROR! entry "+entry+" in alexandria_sheet does not match"
				" any samples listed in the sample sheet")
		print("FOUND entry", entry)

	def get_validated_bcl_sheet(self, bcl_path, bucket_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		print("ALEXANDRIA: Finding sequencing run sample sheet for", osp.basename(bcl_path))
		bcl_sheet_path = self.get_bcl_sheet_path(bcl_path, bucket_slash)
		print("Searching for sample sheet:", bcl_sheet_path)
		ss = self.get_trimmed_bcl_sheet(bcl_sheet_path)
		print("Finding and checking samples listed in alexandria_sheet")
		print("--------------------------")
		entries = self.get_entries(bcl_path, bcl_sheet_path)
		entries.apply(func=self.check_entry, args=(ss,))
		return bcl_sheet_path

	def setup_bcl2fastq_sheet(self, bucket_slash):
		print("--------------------------")
		print("ALEXANDRIA: is_bcl is set to true, will be checking ", self.BCL_path, "as well as optional", self.SS_path, "column.")
		if not self.BCL_path in self.sheet.columns:
			raise Exception("ALEXANDRIA: ERROR! Missing required column '"+self.BCL_path+"'")
		tool_sheet = pd.DataFrame()
		tool_sheet[self.BCL_path] = self.sheet[self.BCL_path].unique()
		tool_sheet[self.BCL_path].apply(
			func=self.check_sequencing_run_path,
			args=(bucket_slash,)
		)
		tool_sheet[self.SS_path] = tool_sheet[self.BCL_path].apply(
			func=self.get_validated_bcl_sheet,
			args=(bucket_slash,)
		)
		self.sheet.to_csv("wtf.tsv", sep='\t', header=True, index=False)
		tool_sheet.to_csv(self.name+"_locations.tsv", header=False, sep='\t', index=False)

	#############################################################################################################################
	#	FASTQs
	#############################################################################################################################

	def check_path_columns(self):
		if not self.R1_path in self.sheet.columns:
			print("No '"+self.R1_path+"' column found in alexandria_sheet, will consign as NaN and handle as such.")
			self.sheet[self.R1_path] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)
		if not self.R2_path in self.sheet.columns:
			print("No '"+self.R2_path+"' column found in alexandria_sheet, will consign as NaN and handle as such.")
			self.sheet[self.R2_path] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)

	def construct_default_fastq_path(self, bucket_slash, fastq_directory_slash, entry, read):
		if fastq_directory_slash.startswith("gs://"): 
			return fastq_directory_slash+entry+"_*R"+read+"*.fastq*" # TODO: Does SS2 allow uncompressed fastqs?
		else: 
			return bucket_slash+fastq_directory_slash+entry+"_*R"+read+"*.fastq*"

	def determine_fastq_path(self, entry, read, default_path, bucket_slash, entered_path):
		print("For", entry, "read", read+":")
		if entered_path == "NaN":
			print("Path was not entered in alexandria_sheet, checking the constructed default path:\n" + default_path)
			return default_path
		elif entered_path.startswith("gs://"):
			print("Checking entered path that begins with gsURI, checking:\n" + entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			print("Checking entered path:\n" + bucket_slash + entered_path)
			return bucket_slash + entered_path

	def validate_fastq_path(self, fastq_path, default_path):
		# First Check the fastq_path, then if it fails then check the fastq default directory.
		try:
			fastq_path = sp.check_output(args=["gsutil", "ls", fastq_path]).strip().decode()
		except sp.CalledProcessError: 
			print("ALEXANDRIA: WARNING! The file was not found at:\n" +fastq_path+ "\nChecking the fastq_directory variable...")
			try: 
				fastq_path = sp.check_output(args=["gsutil", "ls", default_path]).strip().decode() # Tries again for default path
			except sp.CalledProcessError: 
				raise Exception("ALEXANDRIA: ERROR! Checked path "+fastq_path+", the fastq(.gz) was not found!")
		print("FOUND", fastq_path)
		print("--------------------------")
		return fastq_path

	def get_entered_fastq_path(self, entry, read):
		if read in self.R1_path:
			fastq_column = self.R1_path
		elif read in self.R2_path:
			fastq_column = self.R2_path
		else:
			raise Exception("ALEXANDRIA DEV: Read was not found in either R1_path or R2_path.")
		# At the intersection of entry and fastq_column, locate the fastq path
		fastq_path = self.sheet.loc[ self.sheet[self.entry] == entry, fastq_column]
		return fastq_path.to_string(index=False).strip()
	
	def get_validated_fastq_path(self, entry, read, bucket_slash, fastq_directory_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		entered_path = self.get_entered_fastq_path(entry, read)
		default_path = self.construct_default_fastq_path(bucket_slash, fastq_directory_slash, entry, read)
		fastq_path = self.determine_fastq_path(entry, read, default_path, bucket_slash, entered_path)
		validated_fastq_path = self.validate_fastq_path(fastq_path, default_path)
		return validated_fastq_path

	def setup_fastq_sheet(self, bucket_slash, fastq_directory_slash):
		print("--------------------------")
		print("ALEXANDRIA: is_bcl is set to false, will be checking", self.entry, "column "
			"as well as", self.R1_path, "and", self.R2_path, "columns.")
		tool_sheet = pd.DataFrame()
		tool_sheet[self.entry] = self.sheet[self.entry]
		self.check_path_columns()
		tool_sheet[self.R1_path] = self.sheet[self.entry].apply(
			func=self.get_validated_fastq_path,
			args=('1', bucket_slash, fastq_directory_slash)
		)
		tool_sheet[self.R2_path] = self.sheet[self.entry].apply(
			func=self.get_validated_fastq_path, 
			args=('2', bucket_slash, fastq_directory_slash)
		)
		self.write_locations(tool_sheet)
		return tool_sheet

	#############################################################################################################################
	#	CUMULUS SETUP
	#############################################################################################################################

	def construct_default_mtx_path(self, bucket_slash, output_directory_slash, entry):
		if output_directory_slash.startswith("gs://"): 
			return output_directory_slash + entry + '/' + entry + self.MTX_extension
		else: 
			return bucket_slash + output_directory_slash + entry + '/' + entry + self.MTX_extension

	def determine_mtx_path(self, entry, bucket_slash, default_path, entered_path):
		print("For", entry+":")
		if entered_path == "NaN":
			print("Path was not entered in alexandria_sheet, checking the constructed default path:\n" + default_path)
			return default_path
		elif entered_path.startswith("gs://"):
			print("Checking entered path that begins with gsURI, checking:\n" + entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			print("Checking entered path:\n" + bucket_slash + entered_path)
			return bucket_slash + entered_path

	def validate_mtx_path(self, mtx_path):
		print("Searching for count matrix at", mtx_path)
		try:
			sp.check_call(args=["gsutil", "ls", mtx_path], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! "+mtx_path+" was not found. Ensure that the path "
				"is correct and that the count matrix is in <name>"+self.MTX_extension+" format!"
			)
		print("FOUND", mtx_path)
		print("--------------------------")
		return mtx_path

	def get_validated_mtx_location(self, entry, bucket_slash, output_directory_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		if not self.MTX_path in self.sheet.columns:
			self.sheet[self.MTX_path] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)
		entered_path = self.sheet.loc[ self.sheet[self.entry] == entry, self.MTX_path] \
			.head(1).to_string(index=False).strip()
		default_path = self.construct_default_mtx_path(bucket_slash, output_directory_slash, entry)
		mtx_path = self.determine_mtx_path(entry, bucket_slash, default_path, entered_path)
		validated_mtx_path = self.validate_mtx_path(mtx_path)
		return validated_mtx_path

	def setup_cumulus_sheet(self, reference, bucket_slash, output_directory_slash):
		cumulus_sheet = pd.DataFrame()
		cumulus_sheet["Sample"] = self.sheet[self.entry]
		cumulus_sheet["Location"] = self.sheet[self.entry].apply(
			func=self.get_validated_mtx_location, 
			args=(bucket_slash, output_directory_slash)
		)
		cumulus_sheet.insert(1, "Reference", \
			pd.Series(cumulus_sheet["Sample"].map(lambda x: reference)) \
		)
		return cumulus_sheet

	#############################################################################################################################
	#	SCP OUTPUTS
	#############################################################################################################################

	def serialize_scp_outputs(self, scp_outputs_list):
		names = ["X_fitsne.coords.txt", "expr.txt", "metadata.txt"] #diffmap pca???
		with open (scp_outputs_list, 'r') as scp_outputs:
			for name in names:
				is_found = False
				for path in scp_outputs:
					path = path.strip('\n')
					os.rename(path, osp.basename(path))
					path = osp.basename(path)
					if path.endswith("X_fitsne.coords.txt"): # Find cluster file
						cluster_file = path
					if path.endswith(name): # Serialize whatever file path
						open(name, 'w').write(path)
						is_found = True
						break
				if is_found is False:
					raise Exception("Path to "+name+" file was not found.")
		return cluster_file

	def transform_cluster_file(self, cluster_file):
		alexandria_metadata = pd.read_csv(cluster_file, dtype=str, sep='\t', header=0)
		alexandria_metadata = alexandria_metadata.drop(columns=['X','Y'])
		def get_entry(entry):
			if entry == "TYPE":
				return "group"
			else:
				return '-'.join(entry.split('-')[:-1]) # Get everything before the first hyphen
		alexandria_metadata.insert(1, "Channel", pd.Series(alexandria_metadata["NAME"].map(get_entry)))
		return alexandria_metadata

	def isolate_metadata_columns(self):
		drop_columns=[value for value in vars(self).values() if isinstance(value, str) and value is not self.entry]
		self.sheet = self.sheet.drop(columns=drop_columns, errors="ignore")

	def get_metadata(self, entry, metadata, metadata_type_map):
		# TODO: Support outside metadata? Type cast data to validate that numeric is int/float, group is whatever.
		attribute_type = metadata_type_map.loc[metadata_type_map.attribute == metadata, "type"].to_string(index=False).strip()
		if attribute_type == "string" or attribute_type == "boolean" or attribute_type == "group":
			attribute_type = "group"
		elif attribute_type == "number" or attribute_type == "numeric":
			attribute_type = "numeric"
		else:
			raise Exception("ALEXANDRIA: ERROR! attribute type "+attribute_type+" is not a recognized value! "
				"Valid values for Alexandria Metadata Convention: ('string', 'number', 'boolean').")
		if entry == "group":
			# For TYPE row, search for type in map
			return attr
		else:
			# For all rows below, get the metadata at entry
			return self.sheet.loc[ self.sheet[self.entry] == entry, metadata].to_string(index=False).strip()

	def map_metadata(self, alexandria_metadata, metadata_type_map):
		metadata_type_map = pd.read_csv(metadata_type_map, dtype=str, header=0, sep='\t')
		for metadata in self.sheet.columns:
			if metadata == self.entry:
				continue
			alexandria_metadata[metadata] = alexandria_metadata["Channel"].apply(
				func=self.get_metadata, 
				args=(metadata, metadata_type_map)
			)
		return alexandria_metadata