import alxlogging
import subprocess as sp
import pandas as pd
import numpy as np
import os
import os.path as osp

class Alexandria(object):
	
	def __init__(self, dictionary): 
		self.__dict__ = dictionary
		if not "name" in dictionary.keys():
			raise Exception("ALEXANDRIA: ERROR! The tool must have a name.")
		if not "sheet" in dictionary.keys():
			raise Exception("ALEXANDRIA: ERROR! The tool must have a sample sheet.")
		if not "entry" in dictionary.keys():
			raise Exception("ALEXANDRIA: ERROR! The tool must have a column header for entry identifiers.")
		self.sheet = self.make_dataframe(self.sheet)
		self.metadata_convention = self.get_metadata_convention()
		self.log = alxlogging.AlxLog()

	#############################################################################################################################
	#	COMMON INPUTS/OUTPUTS
	#############################################################################################################################

	@classmethod
	def get_tool(cls, name, sheet):
		from alxpresets import Dropseq, Smartseq2, Kallisto_Bustools, Cellranger
		name = name.replace('-', '').replace('_','').lower()
		if name == "dropseq":
			return Dropseq(sheet)
		elif name == "smartseq2":
			return Smartseq2(sheet)
		elif name == "kallistobustools":
			return Kallisto_Bustools(sheet)
		elif name == "cellranger":
			return Cellranger(sheet)
		else:
			raise Exception(f"ALEXANDRIA: ERROR! Preset {name} is invalid must be one of the "
				"valid options: (Dropseq, Smartseq2, Kallisto_Bustools, Cellranger)"
			)

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
		# Defined by preset
		pass

	def check_bucket(self, bucket):
		self.log.info(f"Checking bucket at gsURI '{bucket}'.")
		try: 
			sp.check_call(args=["gsutil", "ls", bucket], stdout=sp.DEVNULL)
		except sp.CalledProcessError:
			raise Exception(f"ALEXANDRIA: ERROR! Bucket {bucket} was not found.")
	
	def check_custom_reference(self, reference):
		if not reference.startswith("gs://"):
			raise Exception(
				f"ALEXANDRIA: ERROR! Custom reference {reference} must be on a "
				"Google bucket and entered as the full gsURI path!"
			)
		try: 
			sp.check_call(args=["gsutil", "ls", reference], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception(f"ALEXANDRIA: ERROR! Custom reference at {reference} was not found.")

	def check_reference(self, reference):
		if self.custom_reference_extension is not None:
			for extension in self.custom_reference_extension:
				if reference.endswith(extension):
					self.check_custom_reference(reference)
		elif reference not in self.provided_references:
			raise Exception(
				f"ALEXANDRIA: ERROR! {reference} does not match a provided reference "
				f"({', '.join(self.provided_references)}) or does not have a valid filename extension."
			) 
		self.log.info(f"Passing reference {reference}.")

	def check_aligner(self, aligner):
		if aligner is not None and aligner not in self.aligners:
			raise Exception(
				f"ALEXANDRIA: ERROR! Aligner '{aligner}' does not match a valid aligner: "
				f"({', '.join(self.aligners)})."
			)

	def get_metadata_convention(self, version="latest"):
		self.log.info("Fetching Alexandria Metadata Convention from the Single Cell Portal")
		import requests
		request = requests.get(
			"https://singlecell.broadinstitute.org/single_cell/api/v1/"
			f"metadata_schemas/alexandria_convention/{version}/tsv"
		)
		if request.status_code is not 200:
			raise Exception(
				"ALEXANDRIA: ERROR! Call to Single Cell Portal for Alexandria Metadata Convention "
				f"version '{version}' returned status code of {request.status_code}"
			)
		filename = f"AMC_{version}.tsv"
		open(filename, 'w').write(request.text)
		return pd.read_csv(filename, sep='\t')

	def check_metadata_headers(self):
		if self.metadata_convention is None:
			raise Exception("ALEXANDRIA: ERROR! No metadata convention was given.")
		ignore_columns=[value for value in vars(self).values() if isinstance(value, str)]
		metadata_headers = self.metadata_convention["attribute"].tolist()
		self.log.info("Checking headers of all metadata columns.")
		for col in self.sheet.drop(columns=ignore_columns, errors="ignore").columns:
			if not col in metadata_headers: # TODO: Warn user? but allow extraneous metadata.
				raise Exception(f"ALEXANDRIA: ERROR! Metadata {col} is not a valid metadata type.")

	def concatenate_sheets(self, sheets):
		df = pd.DataFrame(columns=[self.entry, self.R1_path, self.R2_path])
		for sheet in sheets:
			sheet = pd.read_csv(
				sheet, 
				sep='\t', 
				usecols=[i for i in range(3)],
				names=[self.entry, self.R1_path, self.R2_path]
			)
			df = pd.concat(objs=[df, sheet], join="outer")
		return df

	def get_plate(self, entry, that):
		#Bcl2fastq --> SS2
		pass

	def write_locations(self, sheet=None, sep='\t', header=False):
		if sheet is None:
			sheet = self.sheet
		sheet.to_csv(f"{self.name}_locations.tsv", sep=sep, header=header, index=False)

	#############################################################################################################################
	#	BCLs
	#############################################################################################################################

	def check_sequencing_run_path(self, bcl_path, bucket_slash):
		self.log.info(f"For BCL_Path entry {osp.basename(bcl_path)}:")
		if bcl_path.startswith("gs://") is False:
			bcl_path = bucket_slash + bcl_path
			self.log.verbose("Prepended the bucket to the entered path.")
		self.log.info("Checking existence of sequencing run directory")
		self.log.verbose(bcl_path)
		try: 
			sp.check_call(args=["gsutil", "ls", bcl_path], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! Sequencing run directory was not found:\n" + bcl_path)
		self.log.info(f"FOUND {bcl_path}")
		self.log.sep()
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
			bcl_sheet = sp.check_output(
				args=["gsutil", "cat", bcl_sheet_path]
			).strip().decode()
		except sp.CalledProcessError: 
			raise Exception(f"ALEXANDRIA: ERROR! Checked for {bcl_sheet}, sample sheet was not found in {bcl_sheet_path}")
		self.log.info("FOUND BCL directory sample sheet.")
		self.log.verbose(bcl_sheet_path)
		with open("trimmed_bcl_sheet.csv", 'w') as ss:
			ss.write(bcl_sheet.split("[Data]")[-1]) # Trims sample sheet...
		ss = pd.read_csv("trimmed_bcl_sheet.csv", dtype=str, header=1) # ...to everything below "[Data]"
		if "Sample_Name" not in ss.columns:
			raise Exception(
				"ALEXANDRIA: ERROR! Column 'Sample_Name' was not found in the "
				f"BCL directory sample sheet of {bcl_sheet_path}"
			)
		return ss

	def get_entries(self, bcl_path, bcl_sheet_path):
		entries = self.sheet.loc[ self.sheet[self.BCL_path] == bcl_path, self.entry]
		if len(entries) is not 0: 
			return entries
		else:
			raise Exception(f"ALEXANDRIA: ERROR! Checked alexandria_sheet {bcl_path} no samples were found in {bcl_sheet_path}")

	def check_entry(self, entry, ss):
		self.log.info(f"Checking if {entry} exists in bcl_sheet")
		if not ss.Sample_Name.str.contains(entry, regex=False).any(): # Check if Sample_Name column contains the sample.
			raise Exception(f"ALEXANDRIA: ERROR! entry {entry} in alexandria_sheet does not match"
				" any samples listed in the sample sheet")
		self.log.info(f"FOUND entry {entry}")

	def get_validated_bcl_sheet(self, bcl_path, bucket_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		self.log.info(f"Finding sequencing run sample sheet for {osp.basename(bcl_path)}")
		bcl_sheet_path = self.get_bcl_sheet_path(bcl_path, bucket_slash)
		self.log.info("Searching for sample sheet.")
		self.log.verbose(bcl_sheet_path)
		ss = self.get_trimmed_bcl_sheet(bcl_sheet_path)
		self.log.info("Finding and checking samples listed in alexandria_sheet")
		self.log.sep()
		entries = self.get_entries(bcl_path, bcl_sheet_path)
		entries.apply(func=self.check_entry, args=(ss,))
		return bcl_sheet_path

	def setup_bcl2fastq_sheet(self, bucket_slash):
		self.log.info(
			f"Paremeter is_bcl is enabled, will be checking {self.BCL_path}"
			f" as well as optional {self.SS_path} column."
		)
		self.log.sep()
		if not self.BCL_path in self.sheet.columns:
			raise Exception(f"ALEXANDRIA: ERROR! Missing required column '{self.BCL_path}'")
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
		tool_sheet.to_csv(f"{self.name}_locations.tsv", header=False, sep='\t', index=False)

	#############################################################################################################################
	#	FASTQs
	#############################################################################################################################

	def check_path_columns(self):
		if not self.R1_path in self.sheet.columns:
			self.log.warn(f"No '{self.R1_path}' column found in alexandria_sheet, will consign as NaN and handle as such.")
			self.sheet[self.R1_path] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)
		if not self.R2_path in self.sheet.columns:
			self.log.warn(f"No '{self.R2_path}' column found in alexandria_sheet, will consign as NaN and handle as such.")
			self.sheet[self.R2_path] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)

	def construct_default_fastq_path(self, bucket_slash, fastq_directory_slash, entry, read):
		if fastq_directory_slash.startswith("gs://"): 
			return fastq_directory_slash+entry+"_*R"+read+"*.fastq*" # TODO: Does SS2 allow uncompressed fastqs?
		else: 
			return bucket_slash+fastq_directory_slash+entry+"_*R"+read+"*.fastq*"

	def determine_path(self, entry, entity, bucket_slash, default_path, entered_path):
		self.log.info(f"For {entry} {entity}:")
		if entered_path == "NaN":
			self.log.info("Path was not entered in alexandria sheet, checking the constructed default path.")
			self.log.verbose(default_path)
			return default_path
		elif entered_path.startswith("gs://"):
			self.log.info("Checking entered path that begins with gsURI")
			self.log.verbose(entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			self.log.info("Prepending bucket to entered path and checking.")
			constructed_path = bucket_slash + entered_path
			self.log.verbose(constructed_path)
			return constructed_path


	def validate_fastq_path(self, fastq_path, default_path):
		try: # First, checks the fastq_path. If unsuccessful check the fastq default directory.
			fastq_path = sp.check_output(args=["gsutil", "ls", fastq_path]).strip().decode()
		except sp.CalledProcessError: 
			self.log.warn("The file was not found at the path!")
			self.log.verbose(fastq_path)
			self.log.info("Checking for FASTQ at the default path (fastq_directory)")
			self.log.verbose(default_path)
			try: # Tries again for default path
				fastq_path = sp.check_output(
					args=["gsutil", "ls", default_path]
				).strip().decode()
			except sp.CalledProcessError: 
				raise Exception(f"ALEXANDRIA: ERROR! Checked path {fastq_path}, the fastq(.gz) was not found!")
		if not fastq_path.endswith(".fastq.gz") and not fastq_path.endswith(".fastq"):
			raise Exception("ALEXANDRIA: ERROR! Ensure the FASTQ ends with the .fastq.gz or .fastq extension!")
		self.log.info(f"FOUND {fastq_path}")
		self.log.sep()
		return fastq_path

	def get_entered_fastq_path(self, entry, read):
		if read in self.R1_path:
			fastq_column = self.R1_path
		elif read in self.R2_path:
			fastq_column = self.R2_path
		else:
			raise Exception(f"ALEXANDRIA DEV: Read was not found in either {self.R1_path} or {self.R2_path}.")
		# At the intersection of entry and fastq_column, locate the fastq path
		fastq_path = self.sheet.loc[ self.sheet[self.entry] == entry, fastq_column]
		return fastq_path.to_string(index=False).strip()
	
	def get_validated_fastq_path(self, entry, read, bucket_slash, fastq_directory_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		entered_path = self.get_entered_fastq_path(entry, read)
		default_path = self.construct_default_fastq_path(bucket_slash, fastq_directory_slash, entry, read)
		fastq_path = self.determine_path(entry, f"read {read}", bucket_slash, default_path, entered_path)
		validated_fastq_path = self.validate_fastq_path(fastq_path, default_path)
		return validated_fastq_path

	def setup_fastq_sheet(self, bucket_slash, fastq_directory_slash):
		self.log.info(f"is_bcl is set to false, will be checking {self.entry} column "
			f"as well as {self.R1_path} and {self.R2_path} columns.")
		self.log.sep()
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

	def validate_mtx_path(self, mtx_path):
		self.log.info(f"Searching for count matrix at {mtx_path}.")
		try:
			sp.check_call(args=["gsutil", "ls", mtx_path], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception(
				f"ALEXANDRIA: ERROR! {mtx_path} was not found. Ensure that the path "
				f"is correct and that the count matrix is in <name>{self.MTX_extension} format!"
			)
		if not mtx_path.endswith(self.MTX_extension):
			raise Exception(f"ALEXANDRIA: ERROR! Ensure the matrix ends with '{self.MTX_extension}'!")
		self.log.info(f"FOUND {mtx_path}")
		self.log.sep()
		return mtx_path

	def get_validated_mtx_location(self, entry, bucket_slash, output_directory_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		if not self.MTX_path in self.sheet.columns:
			self.sheet[self.MTX_path] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)
		entered_path = self.sheet.loc[ self.sheet[self.entry] == entry, self.MTX_path ] \
			.head(1).to_string(index=False).strip()
		default_path = self.construct_default_mtx_path(bucket_slash, output_directory_slash, entry)
		mtx_path = self.determine_path(entry, "matrix", bucket_slash, default_path, entered_path)
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
		names = ["X_fitsne.coords.txt", "X_pca.coords.txt", "expr.txt", "metadata.txt"]
		with open (scp_outputs_list, 'r') as scp_outputs:
			for name in names:
				is_found = False
				for path in scp_outputs:
					path = path.strip('\n')
					os.rename(path, osp.basename(path)) # Move file to pwd
					path = osp.basename(path)
					if path.endswith("X_fitsne.coords.txt"): # Find cluster file
						cluster_file = path
					if path.endswith(name): # Serialize whatever file path
						#open(name, 'w').write(path)
						is_found = True
						break
				if is_found is False:
					raise Exception(f"Path to {name} file was not found.")
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
		drop_columns=[
			value for value in vars(self).values() \
				if isinstance(value, str) and value is not self.entry
		]
		self.sheet = self.sheet.drop(columns=drop_columns, errors="ignore")

	def get_attribute_type(self, metadata):
		attribute_type = self.metadata_convention.loc[
				self.metadata_convention.attribute == metadata, "type"
			].to_string(index=False).strip()
		if attribute_type in ["string", "boolean", "group"]:
			return "group"
		elif attribute_type in ["number", "numeric"]:
			return "numeric"
		else:
			raise Exception(f"ALEXANDRIA: ERROR! attribute type {attribute_type} is not a recognized value! "
				"Valid values for Alexandria Metadata Convention: ('string', 'number', 'boolean')."
			)

	def get_metadata(self, entry, metadata):
		# TODO: Support outside metadata? Type cast data to validate that numeric is int/float, group is whatever
		if entry == "group":
			# For TYPE row, search for type in map
			return self.get_attribute_type(metadata)
		else:
			# For all rows below, get the metadata at entry
			return self.sheet.loc[ 
					self.sheet[self.entry] == entry, metadata
				].to_string(index=False).strip()

	def map_metadata(self, alexandria_metadata):
		for sample in alexandria_metadata["Channel"].unique():
			if sample != "group" and sample not in self.sheet[self.entry].tolist():
				raise Exception(f"ALEXANDRIA DEV: {sample} was not found in Alexandria Sheet.")
		for metadata in self.sheet.columns:
			if metadata == self.entry:
				continue
			alexandria_metadata[metadata] = alexandria_metadata["Channel"].apply(
				func=self.get_metadata, 
				args=(metadata,)
			)
		return alexandria_metadata
