import pandas as pd
import numpy as np
import argparse as ap
from tool import *

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-t", "--tool", help="Which tool is/was used (Dropseq, Smartseq2)")
	parser.add_argument("-i", "--input_csv_file", help="Path to the input_csv_file.")
	parser.add_argument("-g", "--bucket_slash", help="gsURI of the Google bucket")
	parser.add_argument("-b", "--is_bcl", help="True or False, whether or not bcl2fastq should be run before dropseq_workflow.", action="store_true")
	parser.add_argument("-r", "--reference", help="The valid reference (hg19, GRCh38, mm10, hg19_mm10, or mmul_8.0.1) or the gsURI to a custom reference.")
	parser.add_argument("-f", "--fastq_directory_slash", help="Path to directory where all FASTQs may be located.", default='', required=False)
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	args = parser.parse_args()

	print("--------------------------")
	tool = Tool.get_tool(args.tool)
	print("ALEXANDRIA: Running setup for", tool.name, "workflow")
	Tool.check_bucket(args.bucket_slash)
	tool.check_reference(args.reference)
	csv = tool.transform_csv_file(args.input_csv_file)
	tool.check_metadata_headers(csv, args.metadata_type_map)
	tls = pd.DataFrame() # The dataframe that becomes the tool locations.tsv, i.e. the input sample sheet for the tool.
	print("--------------------------")
	if args.is_bcl is True: # Generate one column CSV of paths to sequencing runs
		print("ALEXANDRIA: is_bcl is set to true, will be checking ", tool.BCL_path, "as well as optional", tool.SS_path, "column.")
		if not tool.BCL_path in csv.columns:
			raise Exception("ALEXANDRIA: ERROR! Missing required column '"+tool.BCL_path+"'")
		csv[tool.BCL_path] = csv[tool.BCL_path].apply(func=tool.check_sequencing_run_path, args=(args.bucket_slash,))
		tls[tool.BCL_path] = csv[tool.BCL_path].unique()
		tls[tool.SS_path] = tls[tool.BCL_path].apply(func=tool.get_validated_sample_sheet, args=(csv, args.bucket_slash))
	else: # Generate a simple tsv of entries and paths to their FASTQs
		print("ALEXANDRIA: is_bcl is set to false, will be checking", tool.entry, "column as well as optional", tool.R1_path, "and", tool.R2_path, "columns.")
		tls[tool.entry] = csv[tool.entry]
		if tool.plate is not None:
			tls[tool.plate] = csv[tool.plate]
		location_override = tool.determine_location_override(csv)
		if location_override is False: 
			print("No '"+tool.R1_path+"' and '"+tool.R2_path+"' columns found, will be checking default constructed paths for fastq(.gz) files.")
			csv[tool.R1_path] = csv[tool.R2_path] = csv[tool.entry].replace(csv[tool.entry], np.nan) # Make path columns and temporarily fill with NaN 
		tls[tool.R1_path] = csv[tool.entry].apply(func=tool.get_validated_fastq_path, args=('1', csv, location_override, args.bucket_slash, args.fastq_directory_slash))
		tls[tool.R2_path] = csv[tool.entry].apply(func=tool.get_validated_fastq_path, args=('2', csv, location_override, args.bucket_slash, args.fastq_directory_slash))
	tool.write_locations(tls)
	print("ALEXANDRIA: SUCCESS! File "+tool.name+"_locations.tsv was written. Setup for workflow is complete, proceeding to run the workflow.")
	print("--------------------------")
if __name__== "__main__": main()