from alxlogging import AlxLog
from alexandria import Alexandria
import subprocess as sp
import pandas as pd
import numpy as np
import os
import os.path as osp


class Dropseq(Alexandria):

	def __init__(self, sheet):
		self.name = "dropseq"
		self.sheet = super().make_dataframe(sheet)
		self.log = AlxLog()
		self.metadata_convention = super().get_metadata_convention()
		self.entry = "Sample"
		self.provided_references = ["hg19", "mm10", "mmul_8.0.1", "GRCh38"]
		self.custom_reference_extension = [".json"]
		self.R1_path = "R1_Path"
		self.R2_path = "R2_Path"
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"
		self.MTX_path = "DGE_Path"
		self.MTX_extension = "_dge.txt.gz"

	def check_custom_reference(self, reference):
		# This is where the JSON will be read and all paths will be checked to make sure they have the same dirname
		pass # TODO

	def check_dataframe(self):
		errors=[]
		if self.entry not in self.sheet.columns:
			errors.append(f"Please ensure your cell column is named '{self.entry}'.")
		if "R1_fastq" in self.sheet.columns or "R2_fastq" in self.sheet.columns:
			errors.append(f"Please rename both of your FASTQ path column headers to '{self.R1_path}' and '{self.R2_path}'.")
		if errors:
			raise Exception("ALEXANDRIA: ERROR! " + "\n".join(errors))

	def check_entry(self, entry, ss):
		super().check_entry(entry, ss)
		self.log.sep()

class Smartseq2(Alexandria):
	
	def __init__(self, sheet):
		self.name = "smartseq2"
		self.sheet = super().make_dataframe(sheet)
		self.log = AlxLog()
		self.entry = "Cell"
		self.metadata_convention = super().get_metadata_convention()
		self.provided_references = ["GRCh38_ens93filt", "GRCm38_ens93filt"]
		self.aligners = ["star", "hisat2-hca"]
		self.custom_reference_extension = [".tar.gz", ".tgz"]
		self.R1_path = "Read1"
		self.R2_path = "Read2"
		self.plate = "Plate"
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"
		self.MTX_path = "DGE_Path"
		self.MTX_extension = ".dge.txt.gz"

	def check_dataframe(self):
		errors=[]
		if self.entry not in self.sheet.columns and "Sample" in self.sheet.columns:
			self.log.warn("'Cell' column not detected but 'Sample' is, overriding Sample as entry column.")
			self.entry = "Sample"
		if self.entry not in self.sheet.columns:
			errors.append(f"Please ensure your cell column is named '{self.entry}'.")
		if self.R1_path not in self.sheet.columns and "R1_Path" in self.sheet.columns:
			print("'Read1'/'Read2' columns not detected but 'R1_Path'/'R2_Path' are, overriding the latter as FASTQ columns.")
			self.R1_path="R1_Path"
			self.R2_path="R2_Path"
		if self.R1_path in self.sheet.columns and self.plate not in self.sheet.columns: # FASTQs
			# This error is also caught later if they didn't include the optional Read1/Read2 columns
			errors.append(f"For is_bcl=false, please ensure your plate column is present and named '{self.plate}'.")
		if errors:
			raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors))
		
	def check_aligner(self, aligner):
		if not aligner:
			raise Exception("ALEXANDRIA: ERROR! No aligner entered, please enter an aligner!")
		super().check_aligner(aligner)
		self.log.info(f"Passing aligner {aligner}")

	def setup_fastq_sheet(self, bucket_slash, fastq_directory_slash):
		tool_sheet = super().setup_fastq_sheet(bucket_slash, fastq_directory_slash)
		tool_sheet.insert(1, self.plate, pd.Series(self.sheet[self.plate]))
		return tool_sheet

	def check_path_columns(self):
		super().check_path_columns()
		#if not self.plate in self.sheet.columns:
		#	print("No '"+self.plate+"' column found in alexandria_sheet, will consign as UnspecifiedPlate and handle as such.")
		#	self.sheet[self.plate] = self.sheet[self.entry].replace(self.sheet[self.entry], "UnspecifiedPlate")
		if not self.plate in self.sheet.columns:
			raise Exception(f"ALEXANDRIA: ERROR! You must include the '{self.plate}' column in your Alexandria Sheet!")
		if self.sheet[self.plate].isnull().values.any():
			raise Exception(f"ALEXANDRIA: ERROR! Detected missing values in the '{self.plate}' column!")

	def determine_fastq_path(self, entry, read, default_path, bucket_slash, entered_path):
		plate = self.sheet.loc[ self.sheet[self.entry] == entry, self.plate].to_string(index=False).strip()
		print(f"For {entry}, plate {plate}, read {read}:")
		if entered_path == "NaN":
			if read is '2':
				self.log.info("Read2 was left blank, inferring single-end FASTQ. Returning empty.")
				return np.nan #Perhaps return null or ''?
			else:
				self.log.info("Path was not entered in alexandria_sheet, checking the constructed default path:\n" + default_path)
				return default_path
		elif entered_path.startswith("gs://"):
			self.log.info("Checking entered path that begins with gsURI, checking:\n" + entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			self.log.info("Checking entered path:\n" + bucket_slash + entered_path)
			return bucket_slash + entered_path

	def setup_bcl2fastq_sheet(self, bucket_slash):
		if not self.plate in self.sheet.columns:
			self.log.warn(f"No '{self.plate}' column detected! Will look for plate in BCL directory sample sheets.")
			self.sheet[self.plate] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)
		super().setup_bcl2fastq_sheet(bucket_slash)
		self.sheet.to_csv("alexandria_sheet_plates.tsv", sep='\t', header=True, index=False)

	def check_entry(self, entry, ss):
		super().check_entry(entry, ss)
		self.log.info("Checking for the plate")
		plate = self.sheet.loc[ self.sheet[self.entry] == entry, self.plate].to_string(index=False).strip()
		if plate != "NaN":
			self.log.info(f"Found plate {plate} in Alexandria Sheet")
		else:
			self.log.warn(f"No plate found in Alexandria Sheet for {entry}. Proceeding to check BCL sample sheet.")
			if "Sample_Plate" not in ss.columns:
				raise Exception("ALEXANDRIA: ERROR! Column 'Sample_Type' was not found in the BCL directory sample sheet.")
			plate = ss.loc[ss.Sample_Name == entry, "Sample_Plate"].to_string(index=False).strip()
			if plate != "NaN":
				self.log.info(f"Found plate in BCL directory sample sheet for {entry}, changing to {plate}")
				self.sheet.loc[ self.sheet[self.entry] == entry, self.plate] = plate
			else:
				raise Exception("ALEXANDRIA: ERROR! No plate found under 'Sample_Plate' in BCL directory's SampleSheet.")
		self.log.sep()

	def get_plate(self, entry):
		return self.sheet.loc[
			self.sheet[self.entry] == entry, self.plate
		].to_string(index=False).strip()

	def write_locations(self, tool_sheet):
		tool_sheet.to_csv(f"{self.name}_locations.tsv", header=True, index=False) # .csv

	def setup_cumulus_sheet(self, reference, bucket_slash, output_directory_slash):
		self.entry = self.plate
		cumulus_sheet = pd.DataFrame(self.sheet[self.plate].unique(), columns=["Sample"])
		cumulus_sheet["Location"] = cumulus_sheet["Sample"].apply(
			func=self.get_validated_mtx_location, 
			args=(bucket_slash, output_directory_slash)
		)
		if reference == "GRCh38_ens93filt":
			reference = "GRCh38"
		elif reference == "GRCm38_ens93filt":
			reference = "mm10"
		cumulus_sheet.insert(1, "Reference", \
			pd.Series(cumulus_sheet["Sample"].map(lambda x: reference)) \
		)
		return cumulus_sheet

	def construct_default_mtx_path(self, bucket_slash, output_directory_slash, entry):
		if output_directory_slash.startswith("gs://"): 
			return output_directory_slash + entry + self.MTX_extension
		else: 
			return bucket_slash + output_directory_slash + entry + self.MTX_extension

	def transform_cluster_file(self, cluster_file):
		alexandria_metadata = pd.read_csv(cluster_file, dtype=str, sep='\t', header=0)
		alexandria_metadata = alexandria_metadata.drop(columns=['X','Y'])
		def get_entry(entry):
			if entry == "TYPE":
				return "group"
			else:
				return '-'.join(entry.split('-')[1:]) # Get the cell name, everything AFTER the first hyphen
		alexandria_metadata.insert(1, "Channel", pd.Series(alexandria_metadata["NAME"].map(get_entry)))
		return alexandria_metadata

class Kallisto_Bustools(Alexandria):

	def __init__(self, sheet):
		self.name = "kallisto-bustools"
		self.sheet = super().make_dataframe(sheet)
		self.log = AlxLog()
		self.metadata_convention = self.get_metadata_convention()
		self.entry = "Sample"
		self.provided_references = ["mm9", "mm10", "GRCh38", "hg19"]
		self.custom_reference_extension = None
		self.R1_path = "R1_Paths"
		self.R2_path = "R2_Paths"
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"
		self.MTX_path = "MTX_Path"
		self.MTX_extension = ".mtx"

	def check_dataframe(self):
		errors=[]
		if self.entry not in self.sheet.columns:
			errors.append(f"Please ensure your cell column is named '{self.entry}'.")
		if self.R1_path not in self.sheet.columns and "R1_Path" in self.sheet.columns:
			self.log.warn(
				"'R1_Paths'/'R2_Paths' columns not detected but 'R1_Path'/'R2_Path' are, "
				"overriding the latter pair as FASTQ columns."
			)
			self.R1_path="R1_Path"
			self.R2_path="R2_Path"
		if self.R1_path in self.sheet.columns and not self.R2_path in self.sheet.columns:
			errors.append(
				f"Please include an '{self.R2_path}' column. "
				"If your FASTQs are single-end, simply enter 'null' for those entries."
			)
		if errors:
			raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors))

	def check_path_columns(self):
		pass

	def determine_fastq_path(self, entry, read, default_path, bucket_slash, entered_path):
		self.log.info(f"For {entry}, read {read}:")
		if entered_path == "NaN":
			if read is "read 2":
				self.log.warn(f"'{self.R2_path}' entry was left blank, inferring single-end FASTQ. Returning empty.")
				return np.nan #Perhaps return null or ''?
			else:
				raise Exception(f"ALEXANDRIA: ERROR! {self.R1_path} for {entry} left empty!")
		elif entered_path.startswith("gs://"):
			self.log.info("Checking entered path that begins with gsURI.")
			self.log.verbose(entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			self.log.info("Prepending bucket to entered path and checking.")
			constructed_path = bucket_slash + entered_path
			self.log.verbose(constructed_path)
			return constructed_path
	
	def get_entered_fastq_paths(self, entry, read):
		entered_paths = self.get_entered_fastq_path(entry, read)
		return entered_paths.strip(',').split(',')

	def get_validated_fastq_path(self, entry, read, bucket_slash, fastq_directory_slash):
		if fastq_directory_slash is not '':
			self.log.warn("fastq_directory is not supported for this workflow.")
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		paths = self.get_entered_fastq_paths(entry, read)
		for i in range(len(paths)):
			paths[i] = self.determine_path(entry, f"read {read}", bucket_slash, None, paths[i])
			paths[i] = self.validate_fastq_path(paths[i], None)
		return ','.join(paths)

	def construct_default_mtx_path(self, bucket_slash, output_directory_slash, entry):
		if output_directory_slash.startswith("gs://"): 
			return output_directory_slash + "count_" + entry + "/counts_filtered/cells_x_genes.mtx"
		else: 
			return bucket_slash + output_directory_slash + "count_" + entry + "/counts_filtered/cells_x_genes.mtx" 

	def validate_mtx_path(self, mtx_path):
		self.log.info(f"Searching for count matrix at {mtx_path}.")
		try:
			sp.check_call(args=["gsutil", "ls", mtx_path], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			self.log.warn(f"Matrix was not found!")
			self.log.verbose(mtx_path)
			self.log.warn("Trying 'spliced.mtx', the other commonly produced output, instead.")
			spliced_mtx_path = mtx_path.replace("cells_x_genes.mtx", "spliced.mtx")
			self.log.verbose(spliced_mtx_path)
			try:
				sp.check_call(args=["gsutil", "ls", spliced_mtx_path], stdout=sp.DEVNULL)
			except sp.CalledProcessError:
				raise Exception(f"ALEXANDRIA: ERROR! Matrix was not found. Ensure that the path is correct.")
		self.log.info(f"FOUND {mtx_path}")
		self.log.sep()
		return mtx_path

	def write_locations(self, sheet=None, sep='\t', header=True):
		super().write_locations(header=header)

class Cellranger(Alexandria):
	
	def __init__(self, sheet):
		self.name = "cellranger"
		self.sheet = super().make_dataframe(sheet)
		self.log = AlxLog()
		self.entry = "Sample"
		self.MTX_path = "MTX_Path"
		self.MTX_extension = "filtered_feature_bc_matrix.h5"
		self.metadata_convention = super().get_metadata_convention()
		self.provided_references = [
			"GRCh38_v3.0.0", "hg19_v3.0.0", "mm10_v3.0.0", "GRCh38_and_mm10_v3.1.0", 
			"GRCh38_v1.2.0", "GRCh38", "hg19_v1.2.0", "hg19", "mm10_v1.2.0", "mm10", 
			"GRCh38_premrna_v1.2.0", "GRCh38_premrna", "mm10_premrna_v1.2.0", "mm10_premrna"
		]
		self.custom_reference_extension = [".tar.gz", ".tgz"]
		self.reference = "Reference"
		self.flowcell = "Flowcell"
		self.lane = "Lane"
		self.index = "Index"
		self.chemistry = "Chemistry"
		self.data_type = "DataType"
		self.feature_barcode_file = "FeatureBarcodeFile"

	def check_dataframe(self):
		errors=[]
		if self.entry not in self.sheet.columns:
			errors.append(f"Please ensure your entry column is named '{self.entry}'.")
		if self.reference not in self.sheet.columns:
			errors.append(f"Please ensure your reference column is named '{self.entry}'.")
		if self.flowcell not in self.sheet.columns:
			errors.append(f"Please ensure your flowcell column is named '{self.entry}'.")
		if errors:
			raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors))

	def check_chemistry(self):
		for chemistry in self.sheet[self.chemistry]:
			if not chemistry in ["SC3Pv3", "SC3Pv2", "fiveprime", "SC5P-PE", "SC5P-R2", 'auto']:
				raise Exception(
					f"Chemistry {chemistry} does not match an accepted type of chemistry "
					"('SC3Pv3', 'SC3Pv2', 'fiveprime', 'SC5P-PE', 'SC5P-R2', 'auto')"
				)

	def check_data_type(self):
		for data_type in self.sheet[self.data_type]:
			if not data_type in ["adt", "crispr", "rna"]:
				raise Exception(
					f"DataType {data_type} does not match an accepted data type "
					"('adt', 'crispr', 'rna')"
				)
			if data_type is not "rna":
				self.log.warn("Only 'rna' type data can be used to produce SCP files!")

	# Cellranger workflow has its own Reference column that needs checking.
	def check_reference(self, reference=None): 
		if not self.reference in self.sheet.columns:
			raise Exception(f"ALEXANDRIA: ERROR! alexandria_sheet lacks mandatory column '{self.reference}'.")
		for reference in self.sheet[self.reference]:
			super().check_reference(reference)
		if self.chemistry in self.sheet.columns:
			self.check_chemistry()
		if self.data_type in self.sheet.columns:
			self.check_data_type()

	def check_flowcells(self, path, bucket_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		if not path.startswith("gs://"):
			path = bucket_slash + path
		try: 
			sp.check_call(args=["gsutil", "ls", path], stdout=sp.DEVNULL)
		except sp.CalledProcessError:
			raise Exception(f"ALEXANDRIA: ERROR! Object {path} was not found.")

	def setup_cellranger_sheet(self, bucket_slash):
		self.sheet[self.flowcell].apply(
			func=self.check_flowcells,
			args=(bucket_slash,)
		)
		tool_sheet = self.sheet[
			[self.entry, self.flowcell, self.reference]
		]
		optional_columns = [
			self.lane, self.index, self.chemistry, 
			self.data_type, self.feature_barcode_file
		]
		pd.options.mode.chained_assignment = None
		for column in optional_columns:
			if column in self.sheet.columns:
				tool_sheet[column] = self.sheet[column]
		self.write_locations(tool_sheet, sep=',', header=True)

	def setup_bcl2fastq_sheet(self, bucket_slash):
		self.setup_cellranger_sheet(bucket_slash)
		
	def setup_fastq_sheet(self, bucket_slash, fastq_directory_slash):
		if fastq_directory_slash is not '':
			self.log.warn("fastq_directory is not supported for this workflow.")
		self.setup_cellranger_sheet(bucket_slash)

	def construct_default_mtx_path(self, bucket_slash, output_directory_slash, entry):
		if output_directory_slash.startswith("gs://"): 
			return output_directory_slash + entry + '/' + self.MTX_extension
		else: 
			return bucket_slash + output_directory_slash + entry + '/' + self.MTX_extension

	def validate_mtx_path(self, mtx_path):
		self.log.info(f"Searching for count matrix at {mtx_path}.")
		try:
			sp.check_call(args=["gsutil", "ls", mtx_path], stdout=sp.DEVNULL)
		except sp.CalledProcessError:
			self.log.warn("10XV3 Matrix not found, looking for 10XV2 matrix")
			mtx_path = mtx_path.replace(self.MTX_extension, "filtered_gene_bc_matrices_h5.h5")
			try:
				sp.check_call(args=["gsutil", "ls", mtx_path], stdout=sp.DEVNULL)
			except sp.CalledProcessError:
				raise Exception(
					"ALEXANDRIA: ERROR! Matrix was not found. Two paths (shown above) "
					"were attempted. Ensure that the path to the matrix is correct."
				)
		self.log.info(f"FOUND {mtx_path}")
		self.log.sep()
		return mtx_path
	
	def setup_cumulus_sheet(self, reference, bucket_slash, output_directory_slash):
		cumulus_sheet = pd.DataFrame()
		cumulus_sheet["Sample"] = self.sheet[self.entry]
		cumulus_sheet["Location"] = self.sheet[self.entry].apply(
			func=self.get_validated_mtx_location, 
			args=(bucket_slash, output_directory_slash)
		)
		return cumulus_sheet

	