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
		self.entry = "Sample"
		self.provided_references = ["hg19", "mm10", "mmul_8.0.1", "GRCh38"]
		self.custom_reference_extension = ".json"
		self.R1_path = "R1_Path"
		self.R2_path = "R2_Path"
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"
		self.MTX_path = "DGE_Path"
		self.MTX_extension = "_dge.txt.gz"

	def check_custom_reference(self, reference):
		print("This is where the JSON will be read and all paths will be checked to make sure they have the same dirname.")
		pass # TODO

	def check_dataframe(self):
		errors=[]
		if self.entry not in self.sheet.columns:
			errors.append("Please ensure your cell column is named '"+self.entry+"'.")
		if "R1_fastq" in self.sheet.columns or "R2_fastq" in self.sheet.columns:
			errors.append("Please rename both of your FASTQ path column headers to '"+self.R1_path+"'' and '"+self.R2_path+"'.")
		if errors:
			raise Exception("ALEXANDRIA: ERROR! " + "\n".join(errors))

	def check_entry(self, entry, ss):
		super().check_entry(entry, ss)
		print("--------------------------")

class Smartseq2(Alexandria):
	
	def __init__(self, sheet):
		self.name = "smartseq2"
		self.sheet = super().make_dataframe(sheet)
		self.entry = "Cell"
		self.provided_references = ["GRCh38_ens93filt", "GRCm38_ens93filt"]
		self.aligners = ["star", "hisat2-hca"]
		self.custom_reference_extension = ".tar.gz"
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
			print("Cell column not detected but Sample is, overriding Sample as entry column.")
			self.entry = "Sample"
		if self.entry not in self.sheet.columns:
			errors.append("Please ensure your cell column is named '"+self.entry+"'.")
		if self.R1_path not in self.sheet.columns and "R1_Path" in self.sheet.columns:
				#errors.append("Please rename both of your FASTQ path column headers to '"+self.R1_path+"' and '"+self.R2_path+"'.")
				print("Read1/Read2 columns not detected but R1_Path/R2_Path are, overriding the latter as FASTQ columns.")
				self.R1_path="R1_Path"
				self.R2_path="R2_Path"
		if self.R1_path in self.sheet.columns and self.plate not in self.sheet.columns: # FASTQs
			# This error is also caught later if they didn't include the optional Read1/Read2 columns
			errors.append("For is_bcl=false, please ensure your plate column is present and named '"+self.plate+"'.")
		if errors:
			raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors))
		
	def check_aligner(self, aligner):
		if not aligner:
			raise Exception("ALEXANDRIA: ERROR! No aligner entered, please enter an aligner!")
		super().check_aligner(aligner)
		print("Passing aligner", aligner)

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
			raise Exception("ALEXANDRIA: ERROR! You must include the '"+self.plate+"' column in your Alexandria Sheet!")
		if self.sheet[self.plate].isnull().values.any():
			raise Exception("ALEXANDRIA: ERROR! Detected missing values in the '"+self.plate+"' column!")

	def determine_fastq_path(self, entry, read, default_path, bucket_slash, entered_path):
		plate = self.sheet.loc[ self.sheet[self.entry] == entry, self.plate].to_string(index=False).strip()
		print("For", entry, "plate", plate, "read", read+":")
		if entered_path == "NaN":
			if read is '2':
				print("Read2 was left blank, inferring single-end FASTQ. Returning empty.")
				return np.nan #Perhaps return null or ''?
			else:
				print("Path was not entered in alexandria_sheet, checking the constructed default path:\n" + default_path)
				return default_path
		elif entered_path.startswith("gs://"):
			print("Checking entered path that begins with gsURI, checking:\n" + entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			print("Checking entered path:\n" + bucket_slash + entered_path)
			return bucket_slash + entered_path

	def setup_bcl2fastq_sheet(self, bucket_slash):
		if not self.plate in self.sheet.columns:
			print("ALEXANDRIA: WARNING! No '"+self.plate+"' column detected! Will look for plate in BCL directory sample sheets.")
			self.sheet[self.plate] = self.sheet[self.entry].replace(self.sheet[self.entry], np.nan)
		super().setup_bcl2fastq_sheet(bucket_slash)
		self.sheet.to_csv("alexandria_sheet_plates.tsv", sep='\t', header=True, index=False)

	def check_entry(self, entry, ss):
		super().check_entry(entry, ss)
		print("Checking for the plate...")
		plate = self.sheet.loc[ self.sheet[self.entry] == entry, self.plate].to_string(index=False).strip()
		if plate != "NaN":
			print("Found plate", plate, " in Alexandria Sheet")
		else:
			if "Sample_Plate" not in ss.columns:
				raise Exception("ALEXANDRIA: ERROR! Column 'Sample_Type' was not found in the BCL directory sample sheet.")
			plate = ss.loc[ss.Sample_Name == entry, "Sample_Plate"].to_string(index=False).strip()
			if plate != "NaN":
				print("Found plate in BCL directory sample sheet for "+entry+", changing to", plate)
				self.sheet.loc[ self.sheet[self.entry] == entry, self.plate] = plate
			else:
				raise Exception("ALEXANDRIA: ERROR! No plate found under Sample_Plate in BCL directory's SampleSheet.")
		print("--------------------------")

	def get_plate(self, entry, that):
		return that.sheet.loc[ that.sheet[that.entry] == entry, that.plate].to_string(index=False).strip()

	def write_locations(self, tool_sheet):
		tool_sheet.to_csv(self.name+"_locations.tsv", header=True, index=False) # .csv

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

class Kallisto_Bustools(Alexandria):

	def __init__(self, sheet):
		self.name = "kallisto-bustools"
		self.sheet = make_dataframe(sheet)
		self.entry = "Sample"
		self.provided_references = ["mouse", "human", "linnarsson"]
		self.custom_reference_extension = "" # TODO
		self.R1_path = "R1_Paths"
		self.R2_path = "R2_Paths"
		self.BCL_path = "BCL_Path"
		self.SS_path = "SS_Path"
		self.MTX_path = "MTX_Path"
		self.MTX_extension = ".mtx" # Lots of other choices here too...

	def check_dataframe(self):
		errors=[]
		if self.entry not in self.sheet.columns:
			errors.append("Please ensure your cell column is named '"+self.entry+"'.")
		if "R1_Path" in self.sheet.columns or "R2_Path" in self.sheet.columns:
			errors.append("Please rename both of your FASTQ path column headers to '"+self.R1_path+"' and '"+self.R2_path+"'.")
		elif self.R1_path in self.sheet.columns and not self.R2_path in self.sheet.columns:
			errors.append("Please include an 'R2_Paths' column. If your FASTQs are single-end, "
				"simply enter 'null' for those entries."
			)
		if errors:
			raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors))

	def determine_fastq_path(self, entry, read, default_path, bucket_slash, entered_path):
		print("For", entry, "read", read+":")
		if entered_path == "NaN":
			if read is '2':
				print(self.R2_path, "was left blank, inferring single-end FASTQ. Returning empty.")
				return np.nan #Perhaps return null or ''?
			else:
				print("Path was not entered in alexandria_sheet, checking the constructed default path:\n" + default_path)
				return default_path
		elif entered_path.startswith("gs://"):
			print("Checking entered path that begins with gsURI, checking:\n" + entered_path)
			return entered_path
		else: # If not gsURI, prepend the bucket
			print("Checking entered path:\n" + bucket_slash + entered_path)
			return bucket_slash + entered_path

class Cellranger(Alexandria):
	
	def __init__(self, sheet):
		self.name = "cellranger"
		self.sheet = super().make_dataframe(sheet)
		self.entry = "Sample"
		self.provided_references = [
			"GRCh38_v3.0.0", "hg19_v3.0.0", "mm10_v3.0.0", "GRCh38_and_mm10_v3.1.0", 
			"GRCh38_v1.2.0", "GRCh38", "hg19_v1.2.0", "hg19", "mm10_v1.2.0", "mm10", 
			"GRCh38_premrna_v1.2.0", "GRCh38_premrna", "mm10_premrna_v1.2.0", "mm10_premrna"
		]
		self.custom_reference_extension = None
		self.reference = "Reference"
		self.flowcell = "Flowcell"
		self.lane = "Lane"
		self.index = "Index"
		self.chemistry = "Chemistry"
		self.data_type = "DataType"
		self.feature_barcode_file = "FeatureBarcodeFile"

	# Cellranger workflow has its own Reference column that needs checking.
	def check_reference(self, reference=None): 
		if not "Reference" in self.sheet.columns:
			raise Exception("ALEXANDRIA: ERROR! alexandria_sheet lacks mandatory column 'Reference'.")
		for reference in self.sheet[self.Reference]:
			super().check_references(reference)