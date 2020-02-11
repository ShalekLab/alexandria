import pandas as pd
import numpy as np
import subprocess as sp

def determine_location_override(csv):
	location_override = False
	if "R1_Path" in csv.columns and "R2_Path" in csv.columns:
		location_override = True
		print("Found R1_Path and R2_Path columns in input_csv_file, will override and search for paths from those columns.")
	return location_override

def construct_default_path(bucket_slash, fastq_directory_slash, sample, read):
	if fastq_directory_slash.startswith("gs://"): 
		return fastq_directory_slash+sample+'_'+read+"*.fastq*" # TODO: Does SS2 allow uncompressed fastqs?
	else: 
		return bucket_slash+fastq_directory_slash+sample+'_'+read+"*.fastq*"

def determine_fastq_path(sample, read, location_override, default_path, bucket_slash, entered_path):
	if location_override is False or entered_path == "NaN":
		print("For", sample, read+":\nPath was not entered in input_csv_file, checking the constructed default path:\n" + default_path)
		return default_path
	elif entered_path.startswith("gs://"):
		print("For", sample, read+":\nChecking entered path that begins with gsURI, checking:\n" + entered_path)
		return entered_path
	else: # If not gsURI, prepend the bucket
		print("For", sample, read+":\nChecking entered path:\n" + bucket_slash + entered_path)
		return bucket_slash + entered_path

def validate_fastq_path(fastq_path, default_path):
	# First Check the fastq_path, then if it fails then check the default directory.
	try:
		fastq_path = sp.check_output(args=["gsutil", "ls", fastq_path]).strip().decode()
	except sp.CalledProcessError: 
		print("ALEXANDRIA: WARNING! The file was not found at:\n" + fastq_path+ "\nChecking the fastq_directory variable...")
		try: 
			fastq_path = sp.check_output(args=["gsutil", "ls", default_path]).strip().decode() # Tries again but for default path
		except sp.CalledProcessError: 
			raise Exception("ALEXANDRIA: ERROR! Checked path "+fastq_path+", the fastq(.gz) was not found!")
	print("FOUND", fastq_path)
	print("--------------------------")
	return fastq_path

# Essentially main
def get_validated_fastq_path(func):
	def wrapper(sample, read, csv, location_override, bucket_slash, fastq_directory_slash):
		pd.options.display.max_colwidth = 2048 # Ensure the entire cell prints out
		entered_path = func(csv, sample, read) #csv.loc[csv.Sample == sample, read+"_Path"].to_string(index=False).strip()
		default_path = construct_default_path(bucket_slash, fastq_directory_slash, sample, read)
		fastq_path = determine_fastq_path(sample, read, location_override, default_path, bucket_slash, entered_path)
		validated_fastq_path = validate_fastq_path(fastq_path, default_path)
		return validated_fastq_path
	return wrapper