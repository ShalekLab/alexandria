import pandas as pd
import argparse as ap
from alexandria import *

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--alexandria_sheet", help="Path to the alexandria_sheet.")
	parser.add_argument("-t", "--tool", help="The tool used prior to this script: (Dropseq, Smartseq2, Kallisto_Bustools, Cellranger)")
	parser.add_argument("-g", "--bucket", help="gsURI of the bucket")
	parser.add_argument("-c", "--check_inputs", help="Check fundamental inputs as a part of cumulus setup.", action="store_true")
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	parser.add_argument("-r", "--reference", help="The valid reference (hg19, GRCh38, mm10, hg19_mm10, or mmul_8.0.1) or the gsURI to a custom reference.")
	parser.add_argument("-o", "--output_directory", help="Path following the bucket root to the directory where outputs will be located.")
	args = parser.parse_args()

	bucket_slash = args.bucket.strip('/')+'/'
	if args.output_directory is not '':
		output_directory_slash = args.output_directory.strip('/')+'/'
	else:
		output_directory_slash = args.output_directory

	print("--------------------------")
	alexandria = Alexandria.get_tool(args.tool, args.alexandria_sheet)
	alexandria.check_dataframe()
	print("ALEXANDRIA: Running setup for Cumulus workflow")
	if args.check_inputs is True:
		print("Checking inputs...")
		Alexandria.check_bucket(bucket_slash)
		alexandria.check_reference(args.reference)
		alexandria.check_metadata_headers(args.metadata_type_map)
		print("Outputs checked!")
		print("--------------------------")
	print("Generating the Cumulus sample sheet, count_matrix.csv...")
	cumulus_sheet = alexandria.setup_cumulus_sheet(args.reference, bucket_slash, output_directory_slash)
	cumulus_sheet.to_csv("count_matrix.csv", header=True, index=False)
	print("ALEXANDRIA: SUCCESS! Setup for Cumulus Workflow is complete, proceeding to run the workflow.")
	print("--------------------------")
if __name__== "__main__": main()