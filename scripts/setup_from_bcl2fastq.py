import argparse as ap
from alexandria import Alexandria
import pandas as pd

def main(args):

	alx = Alexandria.get_tool(args.tool, args.alexandria_sheet)
	alx.log.info(f"Running setup for {alx.name} from bcl2fastq.")
	alx.check_dataframe()
	alx.log.info("Concatenating Bcl2fastq FASTQ sheets from each converted BCL directory.")
	fastqs = alx.concatenate_sheets(args.bcl2fastq_sheets)
	alx.log.info("Getting plate column from Alexandria Sheet. This column may have been added by the prior script, setup_tool.py.")
	fastqs[alx.plate] = fastqs[alx.entry].apply(
		func=alx.get_plate,
		args=()
	)
	alx.write_locations(fastqs)
	alx.log.success(f"Wrote {alx.name}_locations.tsv! Proceeding to run {alx.name} workflow.")
	alx.log.sep('=')

parser = ap.ArgumentParser()
parser.add_argument("-t", "--tool",
					help="Which tool is/was used (Dropseq, Smartseq2, Cellranger, Kallisto_Bustools)"
)
parser.add_argument("-i", "--alexandria_sheet",
					 help="Path to the alexandria_sheet."
)
parser.add_argument("-b", "--bcl2fastq_sheets", 
					nargs='+', 
					help="Comma-delimited list of bcl2fastq-workflow-outputted fastqs.txt files"
)
args = parser.parse_args()

if __name__== "__main__": main(args)