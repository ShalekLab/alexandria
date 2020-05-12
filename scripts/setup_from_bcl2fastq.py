import argparse as ap
from alexandria import *
import pandas as pd

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-t", "--tool", help="Which tool is/was used (Dropseq, Smartseq2, Cellranger, Kallisto_Bustools)")
	parser.add_argument("-i", "--alexandria_sheet", help="Path to the alexandria_sheet.")
	parser.add_argument("-b", "--bcl2fastq_sheets", nargs='+', help="Comma-delimited list of bcl2fastq-workflow-outputted fastqs.txt files")
	args = parser.parse_args()

	print("--------------------------")
	print("ALEXANDRIA: Running setup from bcl2fastq script.")
	fastqs = Alexandria.get_tool(args.tool, None)
	fastqs.sheet = pd.DataFrame(columns=[fastqs.entry, fastqs.R1_path, fastqs.R2_path])
	print("Concatenating bcl2fastq FASTQ sheets from each converted BCL directory")
	fastqs.concatenate_sheets(args.bcl2fastq_sheets)

	alexandria = Alexandria.get_tool(args.tool, args.alexandria_sheet)
	alexandria.check_dataframe()
	print("Getting plate column from Alexandria Sheet. This may have been added by the setup_tool.py script.")
	fastqs.sheet[fastqs.plate] = fastqs.sheet[fastqs.entry].apply(
		func=fastqs.get_plate,
		args=(alexandria,)
	)
	fastqs.write_locations(fastqs.sheet)
	print("ALEXANDRIA: SUCCESS! Wrote "+alexandria.name+"_locations.tsv! Proceeding to run "+alexandria.name+" workflow.")
	print("--------------------------")
if __name__== "__main__": main()