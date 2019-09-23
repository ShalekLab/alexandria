# Alexandria: A Single-Cell RNA-Seq and Analytics Platform for Global Health

Work-in-progress documentation for the Alexandria platform and all associated tool workflows.

Table of contents.  

* Introduction
* Running dropseq_scCloud on the Single Cell Portal/Alexandria
    - inputs 
    - outputs
* Running dropseq_scCloud on Terra
    - inputs 
    - outputs

Tables generated using https://jakebathman.github.io/Markdown-Table-Generator/

# Running dropseq_scCloud on the Single-Cell Portal

Running the Single-Cell workflow is intended for beginners of single-cell RNA data. Therefore, only essential parameters are exposed.  

Those who would like more options for running the workflow should use the Terra version of the workflow and then transfer/sync the outputs to your SCP workspace study bucket.  

If you truly would like certain parameters to be exposed, please contact jgatter@broadinstitute.org.

### Basic Usage
**Parameter**|**Description**
:------|:------
input\_csv\_file|The spreadsheet (comma-separated value file) uploaded in the miscellaneous tab of your study’s Upload/Edit Study Data page. *Formatting must adhere to the criteria!*
reference|Enter the name of the genome to which you wish to align. Supported options include hg19, mm10, hg19\_mm10, or mmul\_8.0.1. Custom json references and hg38 will be supported in the future.
run\_dropseq|Select Yes to run the [Drop-seq pipeline workflow](https://sccloud.readthedocs.io/en/latest/drop_seq.html) which will align your sequencing data and perform quality control.
(OPTIONAL in 75 or default=False) is\_bcl|Select Yes if all of your data is in BCL format, [bcl2fastq](https://support.illumina.com/content/dam/illumina-support/documents/documentation/software_documentation/bcl2fastq/bcl2fastq_letterbooklet_15038058brpmi.pdf) will be run to convert your data to fastq.gz. Select No if all of your data is of fastq.gz type.
(OPTIONAL in 75) dropseq\_default\_directory|If all of your sequence data are located within the same folder on your bucket, enter the path to that folder starting from the bucket. Ex: Enter data/mouse\_fastqs for folder mouse\_fastqs located at the following gsURL: gs://[bucket ID]/data/mouse\_fastqs/. If not applicable, view the documentation to learn how you can list paths in the input\_CSV\_file.
dropseq\_output\_directory|Enter the path leading to a bucket folder where you wish all of the Drop-seq outputs (aligned data, count matrices, etc.) to be stored. All folders in this path will be created if they do not exist. Ex: Entering data/20190916/aligned will store all Drop-seq outputted files at gsURL gs://[bucketID]/data/20190916/aligned/
run\_scCloud|Select Yes if you wish to create run the [scCloud workflow](https://sccloud.readthedocs.io/en/latest/scCloud.html) which will generate metadata, cluster files, coordinate files to be uploaded into the Alexandria for exploration.
scCloud\_output\_directory|Enter the path leading to a bucket folder where you wish all of the scCloud outputs (expression matrix, metadata, cluster, and coordinate files) to be stored. All folders in this path will be created if they do not exist. Ex: Entering data/20190916/analysis will store all Drop-seq outputted files at gsURL gs://[bucketID]/data/20190916/analysis/

### Advanced Usage
**Parameter**|**Description**
:------|:------
preemptible, default=2|Number of request attempts made for a preemptible virtual machine instance before requesting a higher-cost, faster, non-preemptible instance. See [this Google Cloud documentation page](https://cloud.google.com/preemptible-vms/) for details.
zones, default=“us-east1-d us-west1-a us-west1-b”|The ordered list of zone preferences for requesting a Google machine to run the pipeline. See [this Google Cloud documentation page](https://cloud.google.com/compute/docs/regions-zones/) for details.
scCloud\_output\_prefix, default=“sco”|Enter a name you may wish to prefix to your outputted scCloud files so that you can differentiate them from files from a different job.
alexandria\_version, default=“0.1”|Version tag of the [shaleklab/alexandria](https://hub.docker.com/r/shaleklab/alexandria/tags) dockerfile to use.
dropseq\_tools\_version, default=“2.3.0”|Version of the [regevlab/dropseq](https://hub.docker.com/r/regevlab/dropseq/tags) dockerfile to use for the respective version of dropseq-tools.
scCloud\_version, default=“0.8.0:v1.0”|Version of the [regevlab/](https://hub.docker.com/u/regevlab)sccloud dockerfile to use for the respective version of scCloud.

### 1. Sign In
Visit the [Single Cell Portal](https://portals.broadinstitute.org/single_cell) and at the top-right click "Sign In". Sign in using your broadinstitute.org email account and allow permissions. ![](imgs/scp/sign_in.png)

### 2. Create a New Study
To create a new study, click Add a Study. Alternatively, to run the workflow on a pre-existing study, select "My Studies", click the Upload/Edit Study button for your study of choice and proceed to [upload your sequence data files](#3-uploading-sequence-data-files). ![](imgs/scp/add_study.png)
When you arrive at the New Study page, first enter the name that you and others will use to identify your study.  
  
Then, use the FireCloud Billing Project dropdown menu to select a billing project other than Default Project in order to run workflows in your study. If you do not have a billing project associated with your account, first click the "create a billing project" hyperlink under the Billing Projects header, on the next page click New Billing Project, and then follow the instructions supplied by clicking the ["Instructions on creating Google billing accounts"](https://software.broadinstitute.org/firecloud/documentation/article?id=9762) button.  
  
Next, fill out other fields to your liking, including the "No Data Download Until?" box, the "Public" dropdown menu, the "Use an existing workspace?" dropdown menu, and the "Description" box. ![](imgs/scp/new_study1.png). 
To share your study with others, click the "Share Study" button for however people as you wish to share your study with and then enter in their respective emails and permissions.  
  
Attach external resources or publications that will help viewers understand your study using the "Add an External Resource" button for however documents you wish to share.  
When all fields are filled in to your satisfaction, click the "Create Study" at the bottom. ![](imgs/scp/new_study2.png)

### 3. Uploading Sequence Data Files
When the study is created you will arrive at the Upload/Edit Study page. Since we are running the workflow and do not have any expression matrix, metadata, cluster, or coordinate label files yet, click the "Sequence Data" tab. There are three methods of uploading sequence data:  

1. `gsutil` **HIGHLY RECOMMENDED FOR ALL CASES:** If you have human data, data that is not a FASTQ, BAM, or gzip, or data that is larger than 2GB, you will need to use Google Cloud's [gsutil tool](https://cloud.google.com/storage/docs/gsutil) through your computer's console. You can follow Broad Single Cell Portal's instructions on [how to upload files via gsutil](https://github.com/broadinstitute/single_cell_portal/wiki/Uploading-Files-Using-Gsutil-Tool). It's super fast and not too hard to get the hang of! ![](imgs/scp/sequence_data1.png)
2. If you are looking for something simpler and have non-human FASTQ, BAM, or gzip files that under 2GB, look at the blue fields below. You can upload a file by clicking the "Upload Data File" button and navigating to the file of interest. Once done, enter the name, description, File type, species, whether the data is human or not, and then click "Upload & Save File" and "Save". To add more files that match this criteria, click "Add a Primary Data File" and repeat the process. ![](imgs/scp/sequence_data2.png)
3. A third option is visiting the study's Google Bucket and manually uploading files, but note that this takes a considerable amount of time! Return to "My Studies" through the top-right dropdown menu that has your account name and select the "Show Details" button for your study. On the the details page, scroll down and click the "View Google Bucket" button that is next to the Google Storage Bucket ID. ![](imgs/scp/study_details.png) This button brings you to the Google Cloud Bucket associated with you study which is where all study files are uploaded. Click the "Upload Files" button and navigate to and select your sequence data files and hit the "Open" button. Return to your "My Studies" page and hit the "Upload/Edit Data" button for your study to upload the input CSV file in step 5. ![](imgs/scp/bucket3.png). 

### 4. Uploading Your Input CSV File
When you have finished uploading your sequencing data, proceed to the "Miscellaneous" tab. Here is where you will upload your input_CSV_file (spreadsheet) that will instruct the workflow. The writing of your input CSV file must adhere to the criteria listed in the [Basic Usage](#basic-usage) section.**  
  
If you need to verify that your paths listed in the R1_Path and R2_Path columns or the BCL_Path column are correct, visit your bucket by following the steps in the third option of step 4. Find your sequence data files and click on them to view their URI (gsURL), which should resemble the format `gs://<bucket ID>/path/to/file`. The locations you should enter in your input CSV file should be all characters following the bucket ID and trailing slash, in this case `path/to/file`. Then return to the "Miscellaneous Tab" of the "Upload/Edit Data" page. ![](imgs/scp/bucket2.png)
To upload the input CSV file, click the "Choose File" button and navigate to select your input CSV file. Then set the file type as "Other" and click "Save" under the "Actions" text. ![](imgs/scp/miscellaneous.png)
 
### 5. Launch dropseq_scCloud workflow
**To ensure that your study recognizes all files, return to your "My Studies" page and hit the "Synchronize" button for your study.**
  
On the "My Studies" page, click the name of your study hyperlink. Next, visit the "Analysis" tab which contains your "Submission History" and the interface that allows you to "Submit a Workflow."  

By default you are on the "Select Workflow" tab. Use the dropdown menu to select the dropseq_scCloud workflow. ![](imgs/scp/select_workflow.png)
Then, click on the "Configure Inputs & Submit" tab. Read the table of parameters below and enter the fields for each parameter to your liking. ![](imgs/scp/configuration.png)
Once done, click the "Submit Workflow" button at the bottom to submit the dropseq_scCloud job. Your job is viewable up top underneath the "Submission History" header. ![](imgs/scp/submission_history.png)
Here you will know if the job ran succesfully. Provided the job does not fail within 10 minutes, the job will take about 20 to 45 hours to complete depending on the amount of sequence data you gave it. 

### 6. Advice for Troubleshooting
If the job fails it is recommended you navigate to and read the log file of the task that failed.  
To do this, click the ID hyperlink of the failed job. ![](imgs/scp/fail.png)
Navigate to the log file of the failed task, which in this case is setup_dropseq. ![](imgs/scp/fail2.png)
Evaluate the error based on the message and decide whether you need to move files in your bucket or change and reupload your input CSV file. The latter can be done with `gsutil -m mv [source] [destination]`.  

**Make sure to synchronize your study before relaunching the job.**

### 7. Synchronizing and Exploring Visualization Options
If you study ran through the scCloud task successfully: 
Synchronize your the outputs by clicking the "Sync" button in the "Analysis" tab. ![](imgs/scp/sync_outputs.png)
Visualize the study by clicking the "Explore" tab and then the "View Options" hyperlink to gain more options for analysis. ![](imgs/scp/explore.png)

# Running dropseq_scCloud on Terra

### 1. Sign In
Visit the [Terra by the Broad Institute]() and sign in using your preferred Google email account and complete the user profile registration steps if it is your first time using Terra. ![](imgs/terra/sign_in.png)


