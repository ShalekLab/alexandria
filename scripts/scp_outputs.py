import pandas as pd
import argparse as ap
from alexandria import Alexandria

def main(args):

	alx = Alexandria.get_tool(args.tool, args.alexandria_sheet)
	alx.log.info("Running scp_outputs script.")
	alx.check_dataframe()
	
	alx.log.info("Parsing scp_outputs list...")
	cluster_file = alx.serialize_scp_outputs(args.scp_outputs_list)

	alx.log.info("Transforming cluster_file to make alexandria_metadata.txt...")
	alexandria_metadata = alx.transform_cluster_file(cluster_file)
	
	alx.log.info("Preparing the alexandria_sheet...")
	alx.isolate_metadata_columns()
	
	alx.log.info("Mapping metadata from alexandria_sheet to alexandria_metadata.txt...")
	alexandria_metadata = alx.map_metadata(alexandria_metadata)

	alexandria_metadata.to_csv("alexandria_metadata.txt", sep='\t', index=False)
	alx.log.success("Wrote alexandria_metadata.txt, finishing the dropseq_cumulus workflow.")
	alx.log.sep('=')

parser = ap.ArgumentParser()
parser.add_argument("-i", "--alexandria_sheet",
					help="Path to the alexandria_sheet."
)
parser.add_argument("-t", "--tool",
					help="The tool used prior to this script: (Dropseq, Smartseq2, Kallisto_Bustools, Cellranger)"
)
parser.add_argument("-s", "--scp_outputs_list",
					help="Path to the scp_outputs_list."
)
args = parser.parse_args()

if __name__== "__main__": main(args)