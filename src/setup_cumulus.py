import pandas as pd
import os.path as osp
import argparse as ap
import subprocess as sp
import check_inputs as ci
#from google.cloud import storage as gcs
#from google.oauth2 import service_account as gsa

def transform_csv(input_csv_file):
	csv = pd.read_csv(input_csv_file, dtype=str, header=0)
	for col in csv.columns:
		csv[col] = csv[col].str.strip()
	if "Sample" in csv.columns: 
		csv = csv.dropna(subset=['Sample'])
	else:
		raise Exception("ALEXANDRIA: ERROR! Required column 'Sample' was not found in "+input_csv_file)
	return csv

def generate_sample_sheet(csv, bucket_slash, output_directory_slash, reference):
	cm = pd.DataFrame()
	cm["Sample"] = csv["Sample"]
	
	def get_dge_location(sample, bucket_slash, output_directory_slash):
		location = bucket_slash+output_directory_slash+sample+'/'+sample+"_dge.txt.gz"
		print("Searching for count matrix at", location)
		try:
			sp.check_call(args=["gsutil", "ls", location], stdout=sp.DEVNULL)
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! "+location+" was not found. Ensure that the path is correct and that the count matrix is in <sample>_dge.txt.gz format!")
		print("FOUND", location)
		print("--------------------------")
		return location
	cm["Location"] = csv["Sample"].apply(func=get_dge_location, args=(bucket_slash, output_directory_slash))
	print("Location column added successfully.")
	
	cm.insert(1, "Reference", pd.Series(cm["Sample"].map(lambda x: reference)))
	print("Reference column added successfully.")
	return cm

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--input_csv_file", help="Path to the input_csv_file.")
	parser.add_argument("-g", "--bucket_slash", help="gsURI of the bucket")
	parser.add_argument("-d", "--run_dropseq", help="Whether or not dropseq was run directly prior to setup.", action="store_true")
	#parser.add_argument("-c", "--check_inputs", help="True or False, whether or not to check inputs.") # was considering as name change for run_dropseq
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	parser.add_argument("-r", "--reference", help="The valid reference (hg19, GRCh38, mm10, hg19_mm10, or mmul_8.0.1) or the gsURI to a custom reference.")
	parser.add_argument("-o", "--output_directory_slash", help="Path to directory where outputs will be located.")
	args = parser.parse_args()
	args.output_directory_slash = args.output_directory_slash.strip('/')+'/' # WDL already does this? Delete?

	print("--------------------------")
	print("ALEXANDRIA: Running setup for Cumulus workflow")
	print("Reading the input_csv_file...")
	csv = transform_csv(args.input_csv_file)
	if args.run_dropseq is True:
		print("Checking inputs...")
		ci.check_bucket(args.bucket_slash)
		ci.check_reference(args.reference)
		ci.check_metadata_headers(csv, args.metadata_type_map)
		print("Outputs checked!")
		print("--------------------------")
	print("Generating the Cumulus sample sheet, count_matrix.csv...")
	cm = generate_sample_sheet(csv, args.bucket_slash, args.output_directory_slash, args.reference)
	cm.to_csv("count_matrix.csv", header=True, index=False)
	print("ALEXANDRIA: SUCCESS! Setup for Cumulus Workflow is complete, proceeding to run the workflow.")
	print("--------------------------")
if __name__== "__main__": main()