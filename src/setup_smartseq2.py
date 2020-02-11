import pandas as pd
import numpy as np
import subprocess as sp
import argparse as ap
import check_inputs as ci
import bcl
import fastq as fq

@ci.transform_csv_file
def transform_csv_file(csv):
	is_valid = True
	errors=[]
	if "Cell" not in csv.columns:
		errors.append("Please ensure your cell column is named 'Cell'.")
	if "Plate" not in csv.columns:
		errors.append("Please ensure your plate column is named 'Plate'.")
	if "Read1" in csv.columns or "Read2" in csv.columns:
		errors.append("Please rename both of your FASTQ path column headers to 'R1_Path' and 'R2_Path'.")
	if len(errors) > 0:
		raise Exception("ALEXANDRIA: ERROR! " + "\n ".join(errors)) 
	return csv.dropna(subset=['Cell'])

@ci.check_metadata_headers
def check_metadata_headers():
	return ["Cell", "Plate", "R1_Path", "BCL_Path", "R2_Path", "SS_Path"]

@bcl.get_validated_sample_sheet
def get_validated_sample_sheet():
	return "Cell"

@fq.get_validated_fastq_path
def get_validated_fastq_path(csv, sample, read):
	return csv.loc[csv.Cell == sample, read+"_Path"].to_string(index=False).strip()

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--input_csv_file", help="Path to the input_csv_file.")
	parser.add_argument("-g", "--bucket_slash", help="gsURI of the Google bucket")
	parser.add_argument("-b", "--is_bcl", help="True or False, whether or not bcl2fastq should be run before smartseq2 workflow.", action="store_true")
	parser.add_argument("-r", "--reference", help="The valid reference (hg19, GRCh38, mm10, hg19_mm10, or mmul_8.0.1) or the gsURI to a custom reference.")
	parser.add_argument("-f", "--fastq_directory_slash", help="Path to directory where all FASTQs may be located.", default='', required=False)
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	args = parser.parse_args()

	print("--------------------------")
	print("ALEXANDRIA: Running setup for Smart-seq2 workflow")
	ci.check_bucket(args.bucket_slash)
	ci.check_reference(args.reference)
	csv = transform_csv_file(args.input_csv_file)
	check_metadata_headers(csv, args.metadata_type_map)
	ssl = pd.DataFrame() # The dataframe that becomes smartseq2_locations.tsv, the input Cell sheet of smartseq2_workflow.
	ssl["Cell"] = csv["Cell"]
	ssl["Plate"] = csv["Plate"]
	print("--------------------------")
	if args.is_bcl is True: # Generate one column CSV of paths to sequencing runs
		print("ALEXANDRIA: is_bcl is set to true, will be checking 'BCL_Path' and 'Cell' columns as well as optional 'SS_Path' column.")
		if not "BCL_Path" in csv.columns:
			raise Exception("ALEXANDRIA: ERROR! Missing required column 'BCL_Path'")
		csv["BCL_Path"] = csv["BCL_Path"].apply(func=bcl.check_sequencing_run_path, args=(args.bucket_slash,))
		ssl["BCL_Path"] = csv["BCL_Path"].unique()
		ssl["SS_Path"] = ssl["BCL_Path"].apply(func=get_validated_sample_sheet, args=(csv, args.bucket_slash))
		ssl.to_csv("smartseq2_locations.tsv", header=None, index=False)
		# TODO: Try running SS2 samples in bcl2fastq, use output fastqs.txt to build ss2 sample sheet with R1 and R2 sample sheet.
	else: # Generate a simple CSV of Cells, their Plates, and paths to their FASTQs
		print("ALEXANDRIA: is_bcl is set to false, will be checking 'Cell' and 'Plate' columns as well as optional 'R1_Path' and 'R2_Path' columns.")
		location_override = fq.determine_location_override(csv)
		if location_override is False:
			print("No 'R1_Path' and 'R2_Path' columns found, will be checking default constructed paths for fastq(.gz) files.")
			csv["R1_Path"] = csv["R2_Path"] = csv["Cell"].replace(csv["Cell"], np.nan) # Make path columns and temporarily fill with NaN
		ssl["Read1"] = csv["Cell"].apply(func=get_validated_fastq_path, args=("R1", csv, location_override, args.bucket_slash, args.fastq_directory_slash))
		ssl["Read2"] = csv["Cell"].apply(func=get_validated_fastq_path, args=("R2", csv, location_override, args.bucket_slash, args.fastq_directory_slash))
		ssl.to_csv("smartseq2_locations.tsv", header=True, index=False)
	print("ALEXANDRIA: SUCCESS! File smartseq2_locations.tsv was written. Setup for Smart-seq2 workflow is complete, proceeding to run the workflow.")
	print("--------------------------")
if __name__== "__main__": main()