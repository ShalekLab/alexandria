import argparse as ap
from alexandria import Alexandria
from alxlogging import AlxLog

def main(args):
	
	bucket_slash = args.bucket.strip('/')+'/'
	if args.fastq_directory is not '':
		fastq_directory_slash = args.fastq_directory.strip('/')+'/'
	else:
		fastq_directory_slash = args.fastq_directory
	
	alx = Alexandria.get_tool(args.tool, args.alexandria_sheet)

	alx.log.sep()
	alx.log.info(f"Running setup for {alx.name} workflow")
	alx.check_bucket(bucket_slash)
	alx.check_dataframe()
	alx.check_reference(args.reference)
	alx.check_aligner(args.aligner)
	alx.check_metadata_headers()
	if args.is_bcl is True:
		tool_sheet = alx.setup_bcl2fastq_sheet(bucket_slash)	
	else:
		tool_sheet = alx.setup_fastq_sheet(bucket_slash, fastq_directory_slash)
	alx.log.success(f"File {alx.name}_locations.tsv was written. "
		"Setup for workflow is complete, proceeding to run the workflow."
	)
	alx.log.sep('=')

parser = ap.ArgumentParser()
parser.add_argument("-t", "--tool", 
					help="Which tool to use (Dropseq, Smartseq2, Cellranger, Kallisto_Bustools)"
)
parser.add_argument("-i", "--alexandria_sheet", 
					help="Path to the alexandria_sheet."
)
parser.add_argument("-g", "--bucket", 
					help="Full gsURI of the Google bucket"
)
parser.add_argument("-b", "--is_bcl", 
					help="Run bcl2fastq on the data prior to FASTQ alignment.", 
					action="store_true"
)
parser.add_argument("-r", "--reference", 
					help="The name of the provided reference or the full gsURI to a custom reference.", 
					default=None, 
					required=False
)
parser.add_argument("-a", "--aligner", 
					help="The name of the aligner you wish to use.", 
					default=None, 
					required=False
)
parser.add_argument("-f", "--fastq_directory", 
					help="Path to directory where all FASTQs may be located.", 
					default='', 
					required=False
)
args = parser.parse_args()

if __name__== "__main__": main(args)
