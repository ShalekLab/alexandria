import argparse as ap
from alexandria import *

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-t", "--tool", help="Which tool is/was used (Dropseq, Smartseq2, Cellranger, Kallisto_Bustools)")
	parser.add_argument("-i", "--alexandria_sheet", help="Path to the alexandria_sheet.")
	parser.add_argument("-g", "--bucket", help="Full gsURI of the Google bucket")
	parser.add_argument("-b", "--is_bcl", help="True or False, whether or not bcl2fastq should be run before dropseq_workflow.", action="store_true")
	parser.add_argument("-r", "--reference", help="The name of the provided reference or the full gsURI to a custom reference.", default=None, required=False)
	parser.add_argument("-a", "--aligner", help="The name of the aligner you wish to use.", default=None, required=False)
	parser.add_argument("-f", "--fastq_directory", help="Path to directory where all FASTQs may be located.", default='', required=False)
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	args = parser.parse_args()
	
	bucket_slash = args.bucket.strip('/')+'/'
	if args.fastq_directory is not '':
		fastq_directory_slash = args.fastq_directory.strip('/')+'/'
	else:
		fastq_directory_slash = args.fastq_directory
	alexandria = Alexandria.get_tool(args.tool, args.alexandria_sheet)

	print("--------------------------")	
	print("ALEXANDRIA: Running setup for", alexandria.name, "workflow")
	Alexandria.check_bucket(bucket_slash)
	alexandria.check_dataframe()
	alexandria.check_reference(args.reference)
	alexandria.check_aligner(args.aligner)
	alexandria.check_metadata_headers(args.metadata_type_map)
	if args.is_bcl is True:
		tool_sheet = alexandria.setup_bcl2fastq_sheet(bucket_slash)	
	else:
		tool_sheet = alexandria.setup_fastq_sheet(bucket_slash, fastq_directory_slash)
	print("ALEXANDRIA: SUCCESS! File "+alexandria.name+"_locations.tsv was written. "
		"Setup for workflow is complete, proceeding to run the workflow.")
	print("--------------------------")
if __name__== "__main__": main()