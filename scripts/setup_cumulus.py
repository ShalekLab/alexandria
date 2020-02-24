import pandas as pd
import argparse as ap
import subprocess as sp
from tool import *

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--input_csv_file", help="Path to the input_csv_file.")
	parser.add_argument("-t", "--tool", help="The tool used prior to this script: (dropseq, smartseq2, kallisto-bustools)")
	parser.add_argument("-g", "--bucket_slash", help="gsURI of the bucket")
	parser.add_argument("-c", "--check_inputs", help="Check fundamental inputs as a part of cumulus setup.", action="store_true") # was considering as name change for run_dropseq
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	parser.add_argument("-r", "--reference", help="The valid reference (hg19, GRCh38, mm10, hg19_mm10, or mmul_8.0.1) or the gsURI to a custom reference.")
	parser.add_argument("-o", "--output_directory_slash", help="Path following the bucket root to the directory where outputs will be located.")
	args = parser.parse_args()

	print("--------------------------")
	print("ALEXANDRIA: Running setup for Cumulus workflow")
	tool = Tool.get_tool(args.tool)

	print("Reading the input_csv_file...")
	csv = tool.transform_csv_file(args.input_csv_file)
	if args.check_inputs is True:
		print("Checking inputs...")
		Tool.check_bucket(args.bucket_slash)
		tool.check_reference(args.reference)
		tool.check_metadata_headers(csv, args.metadata_type_map)
		print("Outputs checked!")
		print("--------------------------")
	print("Generating the Cumulus sample sheet, count_matrix.csv...")
	cm = tool.generate_sample_sheet(csv, args.bucket_slash, args.output_directory_slash, args.reference)
	cm.to_csv("count_matrix.csv", header=True, index=False)
	print("ALEXANDRIA: SUCCESS! Setup for Cumulus Workflow is complete, proceeding to run the workflow.")
	print("--------------------------")
if __name__== "__main__": main()