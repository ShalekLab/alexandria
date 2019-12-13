## Formatting Your input_csv_file

Write your input csv file in a text editor or a spreadsheet manipulation program such as Microsoft Excel and save your file as a comma-separated value (.csv) file. The input CSV file must have column headers and contains the following in whatever order:

* **(REQUIRED)** the 'Sample' column, the sample/array names that prefix the respective .fastq(.gz) files/BCL directories and the count matrices outputted by Drop-seq pipeline.

* (OPTIONAL) both 'R1_Path' and 'R2_Path' columns, the paths to .fastq(.gz) files on the bucket. If these columns are not included or if some spreadsheet cells under these columns are left blank, the workflow will check `dropseq_default_directory` by default for unspecified files searching for the pattern `<Sample Name>*<R1 or R2>*.fastq.gz`. As an example, for `gs://bucketID/fastqs/samplename_R1.fastq` you could enter "gs://bucketID/fastqs/samplename_R1.fastq", "fastqs/samplename_R1.fastq", or leave it blank and enter "fastqs" for the `dropseq_default_directory`.

* (OPTIONAL) 'BCL_Path' column, the paths to the BCL directories on the bucket. If not included or if cells are left blank, will check dropseq_default_directory by default. Include this column only if `run_bcl2fastq=true`. R1_Path and R2_Path columns will be ignored if so.

* (OPTIONAL) Other metadata columns that will be appended to the alexandria_metadata.txt (tab-delimited) file generated after running Cumulus. Column labels MUST match EXACTLY the names of the ATTRIBUTE list in the [Alexandria Metadata Convention](https://alexandria-scrna-data-library.readthedocs.io/en/latest/metadata/#the-alexandria-metadata-convention). Labels outside of this convention will be supported in the future ![](imgs/csv.png)

To verify that the paths you listed in the file are correct, you can navigate to your bucket using the instructions listed [above](https://alexandria-scrna-data-library.readthedocs.io/en/latest/terra/#3-add-your-sequence-data-and-input-csv-file) and locate your sequence data files. Click on each file to view its URI (gsURL), which should resemble the format `gs://<bucket ID>/path/to/file.fastq.gz` in the case of `gzip`-compressed FASTQ files (regular FASTQ files are fine too). The locations you should enter in the path columns of your input CSV file should be all of the characters following the bucket ID and trailing slash, in this case `path/to/file.fastq.gz`. ![](imgs/scp/bucket2.png)
  
#### Understanding dropseq_default_directory
The use of [this variable](https://alexandria-scrna-data-library.readthedocs.io/en/latest/dropseq_cumulus/#basic-usage) is not essential and is only meant to help users write their CSV faster. If the snapshot you are using requires `dropseq_default_directory` and you do not wish to use it, just enter an empty string: `""`.

Refer to the above spreadsheet example. There are four samples which each have two FASTQ reads. All FASTQ files are found in a folder located at the root of the bucket called mouse_fastqs. Since they are all located in the same directory, one could set mouse_fastqs as the `dropseq_default_directory` and no longer need to have R1_Path and R2_Path columns. ![](imgs/csv2.png) 
  
If the user has R1_Path and R2_Path columns but leaves spreadsheet cells left blank, the pipeline will search in the `dropseq_default_directory` for the corresponding sample ![](imgs/csv3.png)
Here the pipeline will search the gs://[bucket ID]/mouse_fastqs directory for any spreadsheet cells left blank; DMSO_R2.fastq.gz, LGD_R1.fastq.gz, LKS_CGP_R1.fastq.gz, and LKS_CGP_R2.fastq.gz. The specific pattern the pipeline searches for is `<Sample Name>*<R1 or R2>*.fastq.gz`.

## Inputs of the dropseq_cumulus Workflow
#### Basic Usage
**Variable**|**Description**
:-----------|:--------------
bucket | gsURL of the workspace bucket to which you have permissions, ex: gs://fc-e0000000-0000-0000-0000-000000000000/. This value is not exposed on Alexandria and is locked to the workspace bucket.
input\_csv\_file | Sample sheet (comma-separated value file) uploaded in the miscellaneous tab of this study’s Upload/Edit Study Data page. [**Formatting must adhere to the criteria!**](https://alexandria-scrna-data-library.readthedocs.io/en/latest/dropseq_cumulus/#formatting-your-input_csv_file) 
reference | Genome for alignment. Supported options: hg19, mm10, hg19_mm10, or mmul_8.0.1 
run\_dropseq | Yes: run [Drop-seq pipeline](https://cumulus-doc.readthedocs.io/en/latest/drop_seq.html) (sequence alignment and QC). Sequencing data must be uploaded to the Google bucket associated with this study.
is\_bcl | Yes: [bcl2fastq](https://support.illumina.com/content/dam/illumina-support/documents/documentation/software_documentation/bcl2fastq/bcl2fastq_letterbooklet_15038058brpmi.pdf) will be run to convert all of your BCL directories to fastq.gz. No: all of your data is already of fastq.gz type.
dropseq\_default\_directory | Sequence data directory name for sequence uploaded to the SCP study google bucket. Ex: Enter data/mouse_fastqs for folder mouse_fastqs located at gs://study bucket ID/data/mouse_fastqs/ If not applicable, list paths in the [input_csv_file](http://broad.io/alexandria-format). 
dropseq\_output\_directory | Path to folder name for Drop-seq outputs (aligned data, count matrices, etc.). All folders in this path will be created if they do not exist. Ex: Entering data/20190909/aligned stores Drop-seq outputs at gs:///data/20190909/aligned/
run\_cumulus | Yes: run [cumulus](https://cumulus-doc.readthedocs.io/en/latest/cumulus.html) workflow (generate metadata, cluster files, coordinate files for data exploration in Alexandria). If `run_cumulus` Yes and `run_dropseq` No: each expression matrix must be located within its sample subdirectory in the SCP study google bucket's dropseq_output_directory.
cumulus\_output\_directory | Path to folder name for cumulus outputs (expression matrix, metadata, cluster, and coordinate files). All folders in this path will be created if they do not exist. Ex: Entering data/20190909/analysis stores Drop-seq output files at gs://study bucket ID/data/20190909/analysis/

#### Advanced Usage
**Variable**|**Description**
:-----------|:--------------
preemptible, default=2 | Number of attempts using a preemptible virtual machine before requesting a higher-cost, non-preemptible instance (default = 2). [See Google Cloud documentation](https://cloud.google.com/preemptible-vms/).
zones, default=“us-east1-d us-west1-a us-west1-b” | The ordered list of zone preferences for requesting a Google machine to run the pipeline. See [Google Cloud documentation page](https://cloud.google.com/compute/docs/regions-zones/).
cumulus\_output\_prefix, default=“sco” | Optional prefix for cumulus files to distinguish them from files from a different job.
alexandria\_version, default=“0.1” | Version of the [shaleklab/alexandria](https://hub.docker.com/r/shaleklab/alexandria/tags) dockerfile to use. 
dropseq\_tools\_version, default=“2.3.0” | Version of the [regevlab/dropseq](https://hub.docker.com/r/regevlab/dropseq/tags) dockerfile to use for the respective version of dropseq-tools. 
cumulus\_version, default=“0.8.0:v1.0” | Version of the [regevlab/](https://hub.docker.com/u/regevlab)cumulus dockerfile to use for the respective version of cumulus. 

#### Drop-seq Pipeline and Cumulus Optional Inputs Exposed on Terra

See the [Drop-seq Pipeline workflow documentation](https://cumulus-doc.readthedocs.io/en/latest/drop_seq.html#inputs).  
*NOTE: dropEst does not account for strandedness and therefore its usage is not recommended.*
  
See the [Cumulus workflow documentation](https://cumulus-doc.readthedocs.io/en/latest/cumulus.html#aggregate-matrix).

## Outputs of the dropseq_cumulus workflow

When running the Drop-Seq pipeline and/or Cumulus through dropseq_cumulus, the workflow yields the same outputs as their counterparts.
  
Explicitly, dropseq_cumulus presents the Single-Cell Portal with the alexandria metadata file (alexandria_metadata.txt), the dense expression matrix (ends with .scp.expr.txt), and the two coordinate files (end with .scp.X_diffmap_pca.coords.txt and .scp.X_fitsne.coords.txt).
  

