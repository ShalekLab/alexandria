import subprocess as sp
import pandas as pd

def check_bucket(bucket):
	print("Checking bucket", bucket+"...")
	try: 
		sp.check_call(args=["gsutil", "ls", bucket], stdout=sp.DEVNULL)
	except sp.CalledProcessError:
		raise Exception("ALEXANDRIA: Bucket "+bucket+" was not found.")
	#os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "path_to_your_.json_credential_file"
	#storage_client = gcs.Client()
    #storage_client.get_bucket(name)
	
def check_reference(reference):
	valid_references=["hg19", "mm10", "hg19_mm10", "mmul_8.0.1", "GRCh38"]
	if reference not in valid_references:
		print("ALEXANDRIA: WARNING!", reference, "does not match a valid reference: (hg19, GRCh38, mm10, hg19_mm10, and mmul_8.0.1).")
		print("Inferring", reference, "as a path to a custom reference.")
	else: 
		print("Passing reference", reference)

def check_metadata_headers(func):
	def wrapper(csv, metadata_type_map):
		mtm = pd.read_csv(metadata_type_map, dtype=str, header=0, sep='\t')
		ignore_columns = func()
		metadata_headers = mtm["ATTRIBUTE"].tolist()
		print("Checking headers of all metadata columns.")
		for col in csv.drop(columns=ignore_columns, errors="ignore").columns:
			if not col in metadata_headers: # TODO: Warn user? but allow extraneous metadata.
				raise Exception("ALEXANDRIA: ERROR! Metadata "+col+" is not a valid metadata type")
	return wrapper

def transform_csv_file(func):
	def wrapper(input_csv_file):
		csv = pd.read_csv(input_csv_file, dtype=str, header=0)
		for col in csv.columns:
			csv[col] = csv[col].str.strip()
		csv = func(csv)
		return csv
	return wrapper