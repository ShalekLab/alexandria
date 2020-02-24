import pandas as pd
import argparse as ap

def serialize_scp_outputs(scp_outputs_file, names):
	with open (scp_outputs_file, 'r') as scp_outputs:
		for name in names:
			is_found = False
			for path in scp_outputs:
				path = path.strip('\n')
				if path.endswith("X_fitsne.coords.txt"): # Find cluster file
					cluster_file = path
				if path.endswith(name): # Serialize whatever file path
					open(name, 'w').write(path)
					is_found = True
					break
			if is_found is False:
				raise Exception("Path to "+name+" file was not found.")
	return cluster_file

def transform_cluster_file(cluster_file):
	amd = pd.read_csv(cluster_file, dtype=str, sep='\t', header=0)
	amd = amd.drop(columns=['X','Y'])
	def get_sample(element):
		if element == "TYPE":
			return "group"
		else:
			return '-'.join(element.split('-')[:-1]) # Get everything before the first hyphen
	amd.insert(1, "Channel", pd.Series(amd["NAME"].map(get_sample)))
	return amd

def transform_csv_file(input_csv_file):
	csv = pd.read_csv(input_csv_file, dtype=str, header=0)
	csv = csv.dropna(subset=['Sample'])
	if "R1_Path" in csv.columns and "R2_Path" in csv.columns: 
		csv = csv.drop(columns=["R1_Path", "R2_Path"])
	if "BCL_Path" in csv.columns:
		csv = csv.drop(columns=["BCL_Path"])
	return csv

def map_metadata(csv, amd, metadata_type_map):
	mtm = pd.read_csv(metadata_type_map, dtype=str, header=0, sep='\t') #TERRA
	def get_metadata(element, csv, metadata, mtm):
		# TODO: Support outside metadata? Type cast data to validate that numeric is int/float, group is whatever.
		if element == "group":
			return mtm.loc[mtm.ATTRIBUTE == metadata, "TYPE"].to_string(index=False).strip() # For TYPE row, search for type in map
		else:
			return csv.loc[csv.Sample == element, metadata].to_string(index=False).strip() # For all rows below, get the metadata at element

	for metadata in csv.columns:
		if metadata == "Sample": continue
		amd[metadata] = amd["Channel"].apply(func=get_metadata, args=(csv, metadata, mtm))
	return amd

def main():
	parser = ap.ArgumentParser()
	parser.add_argument("-i", "--input_csv_file", help="Path to the input_csv_file.")
	parser.add_argument("-m", "--metadata_type_map", help="Path to the metadata_type_map.")
	parser.add_argument("-s", "--scp_outputs_file", help="Path to the scp_outputs_file.")
	args = parser.parse_args()

	print("--------------------------")
	print("ALEXANDRIA: Started scp_outputs.py task script.")
	print("Parsing scp_outputs_file...")
	names = ["X_fitsne.coords.txt", "expr.txt", "metadata.txt"] #diffmap pca???
	cluster_file = serialize_scp_outputs(args.scp_outputs_file, names)

	print("Transforming cluster_file to make alexandria_metadata.txt...")
	am = transform_cluster_file(cluster_file)
	
	print("Preparing the input_csv_file...")
	csv = transform_csv_file(args.input_csv_file)
	
	print("Mapping metadata from input_csv_file to alexandria_metadata.txt...")
	alexandria_metadata = map_metadata(csv, am, args.metadata_type_map)

	alexandria_metadata.to_csv("alexandria_metadata.txt", sep='\t', index=False)
	print("ALEXANDRIA: SUCCESS! Wrote alexandria_metadata.txt, finishing the dropseq_cumulus workflow.")
	print("--------------------------")
if __name__== "__main__": main()