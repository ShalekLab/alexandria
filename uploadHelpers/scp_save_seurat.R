library(Seurat)
library(crunch)
load_multiple_seurat_files <- function(files, project_ids, output_prefix, ...) {
  # files is a list of strings that are paths to Rds objects
  # project_ids is a list of strings to name the projects/samples represented by the Rds files in order of input
  # ... arguments passed to main SCP R saving method
  
  for(i in 1:length(files)){
    
    obj_<-load(files[[i]])
    obj <- get(obj_)
    #obj = files[[i]]
    print(obj)
    proj_name <- project_ids[i]
    #obj<-RenameCells(object=obj, add.cell.id = proj_name)
    metadata <- scp_seurat_object(obj, output_prefix= paste(output_prefix, proj_name=proj_name, sep="_"),proj_name=proj_name,  ...)
    # TODO you need to return or merge these metadata objects 
    if(i > 1){
      merged_metadata <- rbindlist(list(merged_metadata, metadata), fill=TRUE)
    }
    else{
      merged_metadata <- metadata
    }
    #rm(obj)
  }
  return(merged_metadata)
}
add_gene_column <- function(seurat_field, proj_name){
  print("project name is:")
  print(proj_name)
  raw_df <- as.data.frame(as.matrix(seurat_field))
  print("finished converting to matrix")
  rownames = row.names(raw_df)
  print("finished changing rownames")
  raw_df_with_rownames = data.frame(GENE = rownames, raw_df) # need a column that says gene
  
  colnames(raw_df_with_rownames) = c('GENE',paste(proj_name, colnames(raw_df), sep="_")) # save gene as columnname
  return( raw_df_with_rownames)
}
save_cluster_file <- function(table_with_reduction, X_name,Y_name, proj_name, output_prefix_reduction){
  # Table with reduction should be a dataframe with cellnames as rows and columns that have at least X_name and Y_name in them
  # X_name is the first axis of this reduction
  # Y_name is the second axis of this reduction
  # proj_name is the name of this dataset
  # output_prefix_reduction is the full path to the filename including the name of the dimensionality reduction you are saving
  dim_red_1 <- table_with_reduction[c(X_name,Y_name)]
  dim_red_2 = data.frame(NAME=paste(proj_name, rownames(dim_red_1), sep="_"),dim_red_1) 
  temp = data.frame(NAME = 'TYPE',
                    x = 'numeric',
                    y = 'numeric')
  colnames(temp) <- c("NAME",X_name, Y_name)
  dim_red_2[[2]] <- as.character(dim_red_2[[2]])
  dim_red_2[[3]] <- as.character(dim_red_2[[3]])
  dim_red_df=rbind.data.frame(temp,dim_red_2)
  colnames(dim_red_df) <-c('NAME','X','Y')
  write.table(file=paste(output_prefix_reduction,"clusterfile.txt", sep="_"),
              quote = FALSE,
              sep = "\t",
              x = dim_red_df,
              row.names = FALSE,
              col.names = TRUE)
  message("wrote cluster file to ",paste(output_prefix_reduction,"clusterfile.txt", sep="_"))
  
}
scp_seurat_object<- function(object, output_prefix, proj_name="", save_raw=FALSE, dim_red_types=c("tsne","umap")){
  
  # save raw counts if requested
  if(save_raw){
    raw_exp_filename <- paste(output_prefix, "_raw_expression_counts.tsv.gz")
    raw_df <- add_gene_column(object@raw.data, proj_name)
    
    write.csv.gz(x=raw_df, file=raw_exp_filename, quote = FALSE,sep = "\t",col.names = TRUE)
    message("Wrote raw expression file to ",raw_exp_filename)
  }
  # save normalized expression data
  
  exp_df <- add_gene_column(object@data,proj_name)
  exp_filename <- paste(output_prefix, "_norm_expression.tsv.gz",sep="")
  
  write.csv.gz(x=exp_df, file=exp_filename, quote = FALSE,sep = "\t",col.names = TRUE)
  message("Wrote norm expression data to ", exp_filename)
  
  for(r in dim_red_types){
    if(paste("X_",r,"1", sep="") %in% colnames(object@meta.data) ){
      save_cluster_file(object@meta.data,paste("X_",r,"1", sep=""), paste("X_",r,"2", sep=""), proj_name, paste(output_prefix,r, sep="_"))
      
    }
  }
  
  metadata<- data.frame(CELLS=paste(proj_name, rownames(object@meta.data), sep="_"), object@meta.data)
  return(metadata)
}

#load_multiple_seurat_files(files=c(Week13.All.Seurat,Week25.All.Cells),project_ids=c("Week13","Week25"),output_prefix = "/Users/nyquist/Dropbox (MIT)/Shalek Lab (Team folder conflict)/Projects/Gates/NIH.Vaccine.Route.Comparison.2019/SCP_")

