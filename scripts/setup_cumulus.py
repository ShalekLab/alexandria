import pandas as pd
import argparse as ap
from alexandria import Alexandria

def main(args):

	bucket_slash = args.bucket.strip('/')+'/'
	if args.output_directory is not '':
		output_directory_slash = args.output_directory.strip('/')+'/'
	else:
		output_directory_slash = args.output_directory

	alx = Alexandria.get_tool(args.tool, args.alexandria_sheet)
	alx.check_dataframe()
	alx.log.info("Running setup for Cumulus workflow")
	if args.check_inputs is True:
		alx.log.info("Checking inputs")
		alx.check_bucket(bucket_slash)
		alx.check_reference(args.reference)
		alx.check_metadata_headers()
		alx.log.info("Outputs checked!")
		alx.log.sep()
	alx.log.info("Generating the Cumulus sample sheet, count_matrix.csv...")
	cumulus_sheet = alx.setup_cumulus_sheet(args.reference, bucket_slash, output_directory_slash)
	cumulus_sheet.to_csv("count_matrix.csv", header=True, index=False)
	alx.log.success("Setup for Cumulus Workflow is complete, proceeding to run the workflow.")
	alx.log.sep('=')

parser = ap.ArgumentParser()
parser.add_argument("-i", "--alexandria_sheet",
					help="Path to the alexandria_sheet."
)
parser.add_argument("-t", "--tool", 
					help="The tool used prior to this script: (Dropseq, Smartseq2, Kallisto_Bustools, Cellranger)"
)
parser.add_argument("-g", "--bucket",
					help="gsURI of the bucket"
)
parser.add_argument("-c", "--check_inputs",
					help="Check fundamental inputs as a part of cumulus setup.",
					action="store_true"
)
parser.add_argument("-r", "--reference",
					help="The valid reference (hg19, GRCh38, mm10, hg19_mm10, or mmul_8.0.1) or the gsURI to a custom reference."
)
parser.add_argument("-o", "--output_directory", 
					help="Path following the bucket root to the directory where outputs will be located."
)
args = parser.parse_args()

if __name__== "__main__": main(args)