library(Seurat)
rm(list = ls()) # Removes all data values from Global Environment to make as much room as possible.
output.dir <- ""
output.prefix <- paste(output.dir, "SCP")

#```

#```{r}
# Paths to .Rds/.Rdata seurat objects. 
# Paste path names in quotation marks on each line and delimit with ',' and a newline.
seurat.paths <- c(
  #"/Users/jggatter/Desktop/Alexandria/alexandria_repository/uploadHelpers/allergen.RData",
  "/Users/jggatter/Desktop/Alexandria/alexandria_repository/uploadHelpers/Split_Up/B_comb.RData"
  #"/Users/jggatter/Desktop/Alexandria/alexandria_repository/uploadHelpers/Split_Up/CD4_comb.RData"
  #"/Users/jggatter/Desktop/Alexandria/alexandria_repository/uploadHelpers/Objects/Week13.All.Seurat.Rdata",
  #"/Users/jggatter/Desktop/Alexandria/alexandria_repository/uploadHelpers/Objects/Week25.All.Seurat.Rdata"
)
if (length(seurat.paths) == 0) stop("No paths were entered.")

# A dataframe that will be composed of Path, Name, Expression Matrix, 
df <- data.frame()
for (path in seurat.paths){
  row <- data.frame(Path=path)
  row$Name <- load(path)
  row$OriginalVersion <- get(row$Name)@version
  
  # Update the Seurat Object to the newest version
  object = UpdateSeuratObject(get(row$Name))
  row$UpdatedVersion <- object@version
  
  # Add the row to the dataframe
  df <- rbind(df, row)
  
  # De-allocate the old Seurat object to save space
  rm(list=c(row$Name))
  
  # TODO: tweak this to prefix cells before merging
  # https://www.rdocumentation.org/packages/Seurat/versions/3.1.1/topics/RenameCells
  RenameCells(object, add.cell.id = row$Name) #for.merge = True, ...
  
  expr.data = object@assays$RNA@data
  expr.filename <- paste(output_prefix, "_norm_expression.txt.gz", sep='')
  expr.df <- add_gene_column(expr.data, row$Name) 
  write.csv.gz(x=expr.df, file=expr.filename, quote=FALSE, sep='\t', col.names=TRUE)
  
  dim.red.df <- updated@meta.data
  # USER INPUT: change these if the column names of your dimensionality reduction are not the ones used below
  X.name <- "X_umap1"
  Y.name <- "X_umap2"
  # USER INPUT: change this to reflect the name of your dimensionality reduction type
  cluster_file_prefix <- paste(output_prefix, row$Name, "umap", sep='_')
  save_cluster_file(dim.red.df, X.name, Y.name, row$Name)
  
  seurat.metadata <- object@meta.data
  merged.metadata <- data.frame(CELLS=paste(row$Name, rownames(seurat.metadata), sep='_'), seurat.metadata)
  
  #De-allocate the updated Seurat object to save space
  rm(object)
}
View(df)

