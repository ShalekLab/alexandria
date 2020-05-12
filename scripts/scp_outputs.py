import pandas as pd
import argparse as ap
from alexandria import *

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--alexandria_sheet", help="Path to the alexandria_sheet.")
	parser.add_argument("-t", "--tool", help="The tool used prior to this script: (Dropseq, Smartseq2, Kallisto_Bustools, Cellranger)")
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	parser.add_argument("-s", "--scp_outputs_list", help="Path to the scp_outputs_list.")
	args = parser.parse_args()

	print("--------------------------")
	print("ALEXANDRIA: Started scp_outputs script.")
	alexandria = Alexandria.get_tool(args.tool, args.alexandria_sheet)
	alexandria.check_dataframe()
	
	print("Parsing scp_outputs list...")
	cluster_file = alexandria.serialize_scp_outputs(args.scp_outputs_list)

	print("Transforming cluster_file to make alexandria_metadata.txt...")
	alexandria_metadata = alexandria.transform_cluster_file(cluster_file)
	
	print("Preparing the alexandria_sheet...")
	alexandria.isolate_metadata_columns()
	
	print("Mapping metadata from alexandria_sheet to alexandria_metadata.txt...")
	alexandria_metadata = alexandria.map_metadata(alexandria_metadata, args.metadata_type_map)

	alexandria_metadata.to_csv("alexandria_metadata.txt", sep='\t', index=False)
	print("ALEXANDRIA: SUCCESS! Wrote alexandria_metadata.txt, finishing the dropseq_cumulus workflow.")
	print("--------------------------")
if __name__== "__main__": main()