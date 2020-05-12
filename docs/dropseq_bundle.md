# Creating a Custom Genome Reference for dropseq_cumulus

```eval_rst
.. Note::

   For now, dropseq_cumulus does not currently does not support upload to Alexandria for matrices containing multiple species. If your data contains data from multiple species, you will need to split your aligned data into multiple matrices such that each matrix contains data from one species. Afterwards, you can run Cumulus only in dropseq_cumulus for each species to generate the necessary files for upload.
```
  
The following information is a summary of [this article by the Cumulus Team](https://cumulus.readthedocs.io/en/latest/drop_seq.html).  
  
dropseq_bundle is a workflow on [Terra](https://terra.bio/) by the Cumulus Team that can produce custom genome references that are compatile with dropseq_workflow (and by extension dropseq_cumulus). Alexandria pipelines are run through Terra, which is the Broad Institute's Cloud Datasciences platform that is built on Google Cloud. Thus, you can use the same Google billing account for Terra that you use for Alexandria/The Single Cell Portal. Once you register, you can follow [this article](terra) to gain a better understanding of how to setup your workspace, import workflows, and run workflows.  
  
Below is a list of important parameters for this workflow.
  
```eval_rst
==================== ===============
 **Parameter Name**  **Description**
==================== ===============
fasta_file           An array of fasta files. If more than one species, fasta and gtf files must be in the same order.
gtf_file             An array of gtf files. If more than one species, fasta and gtf files must be in the same order.
genomeSAindexNbases  Length (bases) of the SA pre-indexing string. Typically between 10 and 15. Longer strings will use much more memory, but allow faster searches. For small genomes, must be scaled down to min(14, log2(GenomeLength)/2 - 1)
==================== ===============
```
You can find genomic FASTA (.fa or .fasta) and GTF (.gtf) files on databases such as NCBI's [RefSeq](https://www.ncbi.nlm.nih.gov/refseq/). You will need to upload these files to your Terra workspace. Note that `fasta_file` and `gtf_file` need to be entered as arrays. For example, you can enter one genomic FASTA as `["gs://<bucket_ID>/path/to/file.fa"]` or multiple as `["gs://<bucket_ID>/path/to/file.fa", "gs://<bucket_ID>/path/to/file2.fa"]` where `gs://<bucket_ID>/path/to/file.fa` will need to be full google storage URI to your files. (e.g. `gs://<bucket_ID>/path/to/<your_gtf>.gtf`, `gs://<bucket_ID>/path/to/<your_fasta>.fasta`, etc.)

After dropseq_bundle runs successfully for your inputs, you can look into [runnning standalone dropseq_workflow](https://cumulus.readthedocs.io/en/latest/drop_seq.html) on Terra. Before doing this, however, you must use the `gsutil mv` command to move each of the dropseq_bundle outputs (listed in the JSON template below) to be in the same folder on your bucket. Then, open your favorite text editor and save a JSON (.json) file of the dropseq_bundle outputs and their new paths using the template below:
```
{
        "refflat":        "gs://<bucket_ID>/path/to/<ref_flat>",
        "genome_fasta":    "gs://<bucket_ID>/path/to/<output_fasta>",
        "star_genome":    "gs://<bucket_ID>/path/to/<index_tar_gz>",
        "gene_intervals":        "gs://<bucket_ID>/path/to/<genes_intervals>",
        "genome_dict":    "gs://<bucket_ID>/path/to/<dict>",
        "star_cpus": 32,
        "star_memory": "240G"
}
```
You will need to replace each `path/to/` string and string in arrow brackets (e.g. ```<string>```) with the information specific to your bucket layout and the files you uploaded. Then, upload this JSON to the Google bucket in which you are running dropseq_cumulus and set `reference` to be the full google storage URI to your JSON. (e.g. `gs://<bucket_ID>/path/to/<your_reference>.json`). You then should follow the instructions from the article listed above to run dropseq_workflow. It is recommended you set the following parameters for good measure:
```
add_bam_tags_disk_space_multiplier = 35
merge_bam_alignment_memory = "32G"
star_disk_space_multiplier = 20
star_extra_disk_space = 100
star_memory = "240G"
drop_deq_tools_dge_memory = "16G"
drop_deq_tools_prep_bam_memory = "16G"
```

Then, run dropseq_cumulus [on Terra](terra) or [on Alexandria](alexandria) with the following parameters:
```
run_dropseq = false
run_cumulus = true
output_path = <output_directory inputted for dropseq_workflow>
reference = <reference inputted for dropseq_workflow>
```
Your Alexandria Sheet can be created from the input_tsv_file used for dropseq_workflow. No need to include 'R1_Path' or 'R2_Path' columns, just make sure the 'Sample' columns matches the sample/array names in the input_tsv_file.