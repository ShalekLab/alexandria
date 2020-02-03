import pandas as pd
import scanpy as sc
import os.path
from pandas.api.types import is_numeric_dtype
import sys
def get_types_df(obs_df):
    datatypes = []
    for i in obs_df.dtypes:
        if is_numeric_dtype(i):
            datatypes.append("numeric")
        else:
            datatypes.append("group")
    datatypes_df = pd.DataFrame([datatypes,], index=["TYPE"], columns=obs_df.columns)
    return datatypes_df

def make_expression_df(adata):
    try: #in case this person didn't save the raw data - this is log not counts?
        out_df = pd.DataFrame(adata.raw.X, index=adata.obs_names, columns=adata.raw.var_names)
    except AttributeError:
        print("No adata.raw saved so using adata.X, this excludes genes that were filtered out and outputs scaled values if scaling has been run")
        out_df = pd.DataFrame(adata.X, index=adata.obs_names, columns=adata.var_names)
    out_df = out_df.T
    out_df.index.name = "GENE"
    return out_df
def make_metadata_df(obs_df):
    datatypes_df = get_types_df(obs_df)

    metadata_df = pd.concat([datatypes_df,obs_df])
    metadata_df.index.name = "NAME"
    return metadata_df
def save_cluster_dfs(adata,output_dir, prefix=""):
    if prefix != "":
        prefix = prefix+"_"
    datatype_df_dimred = pd.DataFrame([["numeric","numeric"],], index= ["TYPE"], columns=["X","Y"])
    for dim_red in adata.obsm.keys(): # obsm is a numpy.recarray
        dim_red_df = pd.DataFrame(index=adata.obs_names)
        dim_red_df["X"] = adata.obsm[dim_red][:,0]
        dim_red_df["Y"] = adata.obsm[dim_red][:,1]
        print("min for "+dim_red+" X is "+str(dim_red_df["X"].min()))
        print("max for "+dim_red+" X is "+str(dim_red_df["X"].max()))
        print("min for "+dim_red+" Y is "+str(dim_red_df["X"].min()))
        print("max for "+dim_red+" Y is "+str(dim_red_df["X"].max()))
        concat_dim_red = pd.concat([datatype_df_dimred,dim_red_df])
        concat_dim_red.index.name = "NAME"

        concat_dim_red.to_csv(os.path.join(output_dir, "cluster_"+prefix+dim_red.split("_")[1]+".txt"))

def convert_adata(adata_file, output_dir):
    # read in adata
    adata = sc.read(adata_file)
    out_df = make_expression_df(adata)
    # first write the data matrix, this needs to be transposed and you want the raw.data if it exists and add the name GENE to the first column
    out_df.to_csv(os.path.join(output_dir, "expression_file.txt.gz"), compression='gzip')
    
    # then write the metadata, you need to choose types for this

    # the way to do that is make a dataframe with one row containing the data type strings and concatinate it with the metadata
    metadata_df = make_metadata_df(adata.obs)
    metadata_df.to_csv(os.path.join(output_dir, "metadata_file.txt"))

    # then write files for cluster files, each dim reduction that exists
    save_cluster_dfs(adata, output_path)
##### Seurat mapping functions start here - probably break into another file ###


def get_metadata_from_seurat(seurat_path, metadata_column):
    '''
    returns a pandas dataframe containing the cell-level metadata from a seruat object saved in 'seurat_path'

    the metadata_column input is to compensate for the fact that different versions of seurat save the metadata in different locations - but I am not positive that is enough
    '''

    # TODO

    # also set a default for metadata_column
    return 
if __name__ == "__main__":
    adata_file = sys.argv[1]
    output_path = sys.argv[2]
    convert_adata(adata_file, output_path)
