import pandas as pd
import subprocess as sp

# Standalone method, nothing to do with the others.
def check_sequencing_run_path(bcl_path, bucket_slash):
	print("ALEXANDRIA: For BCL_Path entry", bcl_path)
	if bcl_path.startswith("gs://") is False:
		bcl_path = bucket_slash + bcl_path
		print("Prepended the bucket to the entry;", bcl_path)
	print("Checking existence of sequencing run directory:", bcl_path)
	try: 
		sp.check_call(args=["gsutil", "ls", bcl_path], stdout=sp.DEVNULL)
	except sp.CalledProcessError: 
		raise Exception("ALEXANDRIA: ERROR! Sequencing run directory at "+bcl_path+" was not found.")
	print("FOUND", bcl_path)
	print("--------------------------")
	return bcl_path.strip('/')+'/'

def get_sample_sheet_path(bcl_path, csv, bucket_slash):
	if "SS_Path" in csv.columns: # If user supplied a column with potential overwrite paths to sample sheet.
		sample_sheet_path = str(csv.loc[csv.BCL_Path == bcl_path, "SS_Path"].iloc[0])
		if sample_sheet_path == "nan":
			sample_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
		elif sample_sheet_path.startswith("gs://") is False:
			sample_sheet_path = bucket_slash + sample_sheet_path #Prepend bucket if not a gsURI
	else:
		sample_sheet_path = bcl_path.strip('/')+"/SampleSheet.csv"
	return sample_sheet_path

def get_trimmed_sample_sheet(sample_sheet_path):
	try: 
		sample_sheet = sp.check_output(args=["gsutil", "cat", sample_sheet_path]).strip().decode()
	except sp.CalledProcessError: 
		raise Exception("ALEXANDRIA ERROR: Checked path "+sample_sheet_path+", sample sheet was not found in "+bcl_path)
	print("FOUND", sample_sheet_path)
	with open("trimmed_sample_sheet.csv", 'w') as ss:
		ss.write(sample_sheet.split("[Data]")[-1]) # Trims sample sheet...
	ss = pd.read_csv("trimmed_sample_sheet.csv", dtype=str, header=1) # ...to everything below "[Data]"
	return ss

def get_samples(bcl_path, csv, entry_column_name, sample_sheet_path):
	samples = csv.loc[csv.BCL_Path == bcl_path, entry_column_name] #csv.loc[csv.BCL_Path == bcl_path, "Sample"] #decorator samples = func
	if len(samples) is not 0: 
		return samples
	else:
		raise Exception("ALEXANDRIA ERROR: Checked input_csv_file "+bcl_path+" no samples were found in"+sample_sheet_path)

def check_sample(sample, ss):
	print("Checking if", sample, "exists in sample_sheet")
	if not ss.Sample_Name.str.contains(sample, regex=False).any(): # Check if Sample_Name column contains the sample.
		raise Exception("ALEXANDRIA ERROR: entry "+sample+" in input_csv_file does not match any samples listed in the sample sheet")
	print("FOUND", sample)

# Essentially main
def get_validated_sample_sheet(func):
	def wrapper(bcl_path, csv, bucket_slash):
		if len(bcl_path) > pd.options.display.max_colwidth:
			pd.options.display.max_colwidth = len(bcl_path) # Ensure the entire cell prints out

		print("ALEXANDRIA: Finding sequencing run sample sheet for", bcl_path)
		sample_sheet_path = get_sample_sheet_path(bcl_path, csv, bucket_slash)

		print("Searching for sample sheet:", sample_sheet_path)
		ss = get_trimmed_sample_sheet(sample_sheet_path)

		print("Finding and checking samples listed in input_csv_file")
		entry_column_name = func()
		samples = get_samples(bcl_path, csv, entry_column_name, sample_sheet_path)
		
		samples.apply(func=check_sample, args=(ss,))
		
		print("--------------------------")
		return sample_sheet_path
	return wrapper