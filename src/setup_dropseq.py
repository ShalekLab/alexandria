import pandas as pd
import numpy as np
import subprocess as sp
import argparse as ap
import check_inputs as ci
import bcl
import fastq as fq

@ci.transform_csv_file
def transform_csv_file(csv):
	if "Sample" not in csv.columns:
		raise Exception("ALEXANDRIA: ERROR! Required column 'Sample' was not found in input_csv_file.")
	return csv.dropna(subset=['Sample'])

@ci.check_metadata_headers
def check_metadata_headers():
	return ["Sample", "R1_Path", "BCL_Path", "R2_Path", "SS_Path"]

@bcl.get_validated_sample_sheet
def get_validated_sample_sheet():
	return "Sample"

@fq.get_validated_fastq_path
def get_validated_fastq_path(csv, sample, read):
	return csv.loc[csv.Sample == sample, read+"_Path"].to_string(index=False).strip()

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--input_csv_file", help="Path to the input_csv_file.")
	parser.add_argument("-g", "--bucket_slash", help="gsURI of the Google bucket")
	parser.add_argument("-b", "--is_bcl", help="True or False, whether or not bcl2fastq should be run before dropseq_workflow.", action="store_true")
	parser.add_argument("-r", "--reference", help="The valid reference (hg19, GRCh38, mm10, hg19_mm10, or mmul_8.0.1) or the gsURI to a custom reference.")
	parser.add_argument("-f", "--fastq_directory_slash", help="Path to directory where all FASTQs may be located.", default='', required=False)
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	args = parser.parse_args()

	print("--------------------------")
	print("ALEXANDRIA: Running setup for Drop-Seq workflow")
	ci.check_bucket(args.bucket_slash)
	ci.check_reference(args.reference)
	csv = transform_csv_file(args.input_csv_file)
	check_metadata_headers(csv, args.metadata_type_map)
	dsl = pd.DataFrame() # The dataframe that becomes dropseq_locations.tsv, the input sample sheet of dropseq_workflow.
	print("--------------------------")
	if args.is_bcl is True: # Generate one column CSV of paths to sequencing runs
		print("ALEXANDRIA: is_bcl is set to true, will be checking 'BCL_Path' and 'Sample' columns as well as optional 'SS_Path' column.")
		if not "BCL_Path" in csv.columns:
			raise Exception("ALEXANDRIA: ERROR! Missing required column 'BCL_Path'")
		csv["BCL_Path"] = csv["BCL_Path"].apply(func=bcl.check_sequencing_run_path, args=(args.bucket_slash,))
		dsl["BCL_Path"] = csv["BCL_Path"].unique()
		dsl["SS_Path"] = dsl["BCL_Path"].apply(func=get_validated_sample_sheet, args=(csv, args.bucket_slash))
	else: # Generate a simple tsv of Samples and paths to their FASTQs
		print("ALEXANDRIA: is_bcl is set to false, will be checking 'Sample' column as well as optional 'R1_Path' and 'R2_Path' columns.")
		dsl["Sample"] = csv["Sample"]
		location_override = fq.determine_location_override(csv)
		if location_override is False: 
			print("No 'R1_Path' and 'R2_Path' columns found, will be checking default constructed paths for fastq(.gz) files.")
			csv["R1_Path"] = csv["R2_Path"] = csv["Sample"].replace(csv["Sample"], np.nan) # Make path columns and temporarily fill with NaN 
		dsl["R1_Path"] = csv["Sample"].apply(func=get_validated_fastq_path, args=("R1", csv, location_override, args.bucket_slash, args.fastq_directory_slash))
		dsl["R2_Path"] = csv["Sample"].apply(func=get_validated_fastq_path, args=("R2", csv, location_override, args.bucket_slash, args.fastq_directory_slash))
	dsl.to_csv("dropseq_locations.tsv", sep='\t', header=None, index=False)
	print("ALEXANDRIA: SUCCESS! File dropseq_locations.tsv was written. Setup for Drop-Seq workflow is complete, proceeding to run the workflow.")
	print("--------------------------")
if __name__== "__main__": main()