import pandas as pd
import argparse as ap
from tool import *

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--input_csv_file", help="Path to the input_csv_file.")
	parser.add_argument("-t", "--tool", help="The tool used prior to this script: (dropseq, smartseq2, kallisto-bustools)")
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	parser.add_argument("-s", "--scp_outputs_list", help="Path to the scp_outputs_list.")
	args = parser.parse_args()

	print("--------------------------")
	print("ALEXANDRIA: Started scp_outputs.py task script.")
	tool = Tool.get_tool(args.tool)
	print("Parsing scp_outputs list...")
	cluster_file = tool.serialize_scp_outputs(args.scp_outputs_list)

	print("Transforming cluster_file to make alexandria_metadata.txt...")
	am = Tool.transform_cluster_file(cluster_file)
	
	print("Preparing the input_csv_file...")
	csv = tool.isolate_metadata_columns(args.input_csv_file)
	
	print("Mapping metadata from input_csv_file to alexandria_metadata.txt...")
	alexandria_metadata = tool.map_metadata(csv, am, args.metadata_type_map)

	alexandria_metadata.to_csv("alexandria_metadata.txt", sep='\t', index=False)
	print("ALEXANDRIA: SUCCESS! Wrote alexandria_metadata.txt, finishing the dropseq_cumulus workflow.")
	print("--------------------------")
if __name__== "__main__": main()