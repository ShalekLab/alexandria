# Kallisto-Bustools workflow
# A publicly available WDL workflow made by Shalek Lab for Kallisto and Bustools wrapped within kb_python
# Workflow by jgatter [at] broadinstitute.org, created November 2019
# FULL DISCLOSURE: many optional parameters remain untested, contact me with bug reports or feature requests
# Kallisto and Bustools made by Pachter Lab. Documentation: https://www.kallistobus.tools/kb_getting_started.html
# -----------------------------------------------------------------------------------------------------------
# INSTRUCTIONS: TWO STEPS, each can be run individually through their respective subworkflows.
# --
# BUILD_REFERENCE: (1) Build or (2) download a transcriptome index
# Set run_build_reference to true, runs only one time and not for the number of samples in your sample sheet.
# Option 1) Build a transcriptome index from reference GTF and FASTA (use_lamanno=true for RNA velocity):
# 	ex: kb ref --verbose (--lamanno) -I index.idx -g transcripts_to_genes.txt -f1 cDNA.fa Mus_musculus.GRCm38.dna.primary_assembly.fa Mus_musculus.GRCm38.98.gtf
# 	Inputs: reference GTF and genomic FASTA, set use_lamanno to true if you want to run RNA velocity
# OR Option 2) Download a pre-built transcriptome index (use_lamanno=true for RNA velocity):
# 	ex: kb ref --verbose (--lamanno) -d mouse -i index.idx -g transcripts_to_genes.txt
# 	Inputs: download_index (“human”, “mouse”, “linnarsson”), use_lamanno=true if you want to run RNA velocity
# Outputs: Kallisto index, T2G mapping, cDNA FASTA, (if use_lamanno==true: intron FASTA, cDNA_transcripts_to_genes.txt, and intron_transcripts_to_genes.txt)
# --
# COUNT: Align your reads and generate a count matrix (use_lamanno=true for RNA velocity)
# Runs each sample in your sample sheet in a parallel count task.
# ex: kb count --verbose (--lamanno) -i index.idx -g transcripts_to_genes.txt -x DROPSEQ -t 32 -m 256G --filter bustools -o ~/count (use_lamanno==true: c1 cDNA_t2c.txt -c2 intron_t2c.txt) R1.fastq.gz (R2.fastq.gz)
# WARNING: This workflow requires each sample to have an R2 FASTQ, use the count subworkflow if using only single-end reads.
# Create a sample_sheet (tab-delimited text file with headers: Sample, R1_Path, R2_Path). R1_Path and R2_Path are full paths to FASTQs on the bucket.
# Inputs: All outputs from the ref step, technology (“DROPSEQ”, “10XV3”, “10XV2”, see kb --list for more), R1_fastq, optional R2_fastq, set use_lamanno=true for RNA velocity,
#	Set nucleus to true for calculating RNA velocity on single-nucleus RNA-seq reads 
#	h5ad or loom to true for outputting expression matrices in those formats.	
#	Barcode whitelist for Seq-Well data will be generated by the program, but if you have one for 10X data you can provide it as an input.
# 	There are several memory parameters you can tweak, but I haven’t noticed any improvements in speed when adjusting them. I’ll investigate it eventually.
#	Specifically, for running with use_lamanno, memory/disk space parameters may require tweaking! Let me know!
# Outputs: Count matrices filtered and unfiltered with their respective barcode and gene lists. Many other files as well.
# -----------------------------------------------------------------------------------------------------------
# SNAPSHOT 11 & 12
# Added VM parameters to pass to subworkflows.
# 


version 1.0

import "https://api.firecloud.org/ga4gh/v1/tools/alexandria_dev:kallisto-bustools_reference/versions/16/plain-WDL/descriptor" as kb_ref
import "https://api.firecloud.org/ga4gh/v1/tools/alexandria_dev:kallisto-bustools_count/versions/21/plain-WDL/descriptor" as kb_count

workflow kallisto_bustools {
	input {
		# REF AND COUNT
		String bucket
		String output_path
		File sample_sheet # Tab-delimited text file with headers: Sample, R1_Path, R2_Path
		Boolean run_build_reference # Runs only one time, not for the number of samples in your sample sheet.
		#Boolean run_cumulus 
		String docker = "shaleklab/kallisto-bustools:0.24.4"
		Int preemptible = 2
		String zones = "us-east1-d us-west1-a us-west1-b"
		Boolean use_lamanno

		# REF
		String? download_index # human mouse linnarsson
		File? genomic_fasta
		File? reference_gtf
		String ref_disks = "local-disk 256 HDD"
		Int ref_number_cpu_threads = 32
		Int ref_task_memory_GB = 128
		Int ref_boot_disk_size_GB = 100

		# COUNT
		String technology # DROPSEQ, 10XV1, 10XV2, 10XV3 or see kb --list for more
		File? preexisting_index # If run_build_reference is false
		File? preexisting_T2G_mapping # If run_build_reference is false
		File? preexisting_cDNA_transcripts_to_capture # If run_build_reference is false
		File? preexisting_intron_transcripts_to_capture # If run_build_reference is false
		Boolean delete_bus_files
		String count_disks = "local-disk 256 SSD"
		Int count_number_cpu_threads = 32
		Int count_task_memory_GB = 256
		Int count_boot_disk_size_GB = 100
	}
	if (run_build_reference) {
		call kb_ref.kallisto_bustools_reference as build_reference {
			input:
				bucket=bucket,
				output_path=output_path,
				docker=docker,
				preemptible=preemptible,
				zones=zones,
				use_lamanno=use_lamanno,
				download_index=download_index,
				genomic_fasta=genomic_fasta,
				reference_gtf=reference_gtf,
				disks=ref_disks,
				number_cpu_threads=ref_number_cpu_threads,
				task_memory_GB=ref_task_memory_GB,
				boot_disk_size_GB=ref_boot_disk_size_GB
		}
	}
	scatter (sample in read_objects(sample_sheet)) {
		call kb_count.kallisto_bustools_count as count {
			input:
				bucket=bucket,
				output_path=output_path,
				docker=docker,
				preemptible=preemptible,
				zones=zones,
				technology=technology,
				use_lamanno=use_lamanno,
				cDNA_transcripts_to_capture=if use_lamanno then select_first([build_reference.cDNA_transcripts_to_capture, preexisting_cDNA_transcripts_to_capture]) else preexisting_cDNA_transcripts_to_capture,
				intron_transcripts_to_capture=if use_lamanno then select_first([build_reference.intron_transcripts_to_capture, preexisting_intron_transcripts_to_capture]) else preexisting_intron_transcripts_to_capture,
				index=select_first([build_reference.index, preexisting_index]),
				T2G_mapping=select_first([build_reference.T2G_mapping, preexisting_T2G_mapping]),
				sample_name=sample.Sample,
				R1_fastq=sample.R1_Path,
				R2_fastq=sample.R2_Path, # R2_Path must be entered, TODO: Handle single-end reads.
				delete_bus_files=delete_bus_files,
				disks=count_disks,
				number_cpu_threads=count_number_cpu_threads,
				task_memory_GB=count_task_memory_GB,
				boot_disk_size_GB=count_boot_disk_size_GB
		}
	}
	#if (run_cumulus) {
	#	call cumulus.cumulus as cumulus {
	#		input:
	#
	#	}
	#}
	output {
		File? index = build_reference.index
		File? T2G_mapping = build_reference.T2G_mapping
		File? cDNA_fasta = build_reference.cDNA_fasta
		File? intron_fasta = build_reference.intron_fasta
		File? cDNA_transcripts_to_capture = build_reference.cDNA_transcripts_to_capture
		File? intron_transcripts_to_capture = build_reference.intron_transcripts_to_capture
		String? ref_output_path = build_reference.ref_output_path

		Array[File?]? counts_unfiltered_matrices = count.counts_unfiltered_matrix
		Array[File?]? counts_filtered_matrices = count.counts_filtered_matrix
		Array[String?]? count_output_paths = count.count_output_path
	}
}