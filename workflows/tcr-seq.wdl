# A publicly available WDL workflow jointly made by MIT's Love Lab and Shalek Lab for the TCR Pipeline
# Workflow By jggatter, andytu, and wadswohm [at] mit.edu, created January 2020
# FULL DISCLOSURE: many configurations remain untested, post an issue on our Github with bug reports or feature requests
# TCR Pipeline made by the andytu [at] mit.edu of Love Lab at the Koch Institute
# TCR Pipeline documentation: https://github.com/jggatter/SeqWell-TCR/tree/master/Seqwell_TCR_processing
# ------------------------------------------------------------------------------------------------------------------------------------------

version 1.0

workflow TCR_pipeline {
	input {		
		# TCR PIPELINE
		String bucket
		String output_path
		
		# Headerless tsv containing for the following columns:
		# [gs://bucket/path/to/bam]	[String reference: "human", "mouse"]	[gs://bucket/path/to/barcode_list]
		# Each row will be scattered.
		File kickoff_inputs

		# VM & MACHINE SETTINGS
		String docker_image = "mitlovelab/seqwelltcranalysis:v1.0" #"mitlovelab/seqwelltcranalysis:v1.0"
		Int number_cpu_threads = 32
		Int boot_disk_size_GB = 100
		String disks = "local-disk 512 HDD"
		Int task_memory_GB = 256
		Int preemptible = 2
		String zones = "us-east1-d us-west1-a us-west1-b"

	}
	String bucket_slash = sub(bucket, '/+$', '') + '/'
	String output_path_slash = sub(output_path, '/+$', '') + '/'
	Array[Array[String]] kickoff_tsv = read_tsv(kickoff_inputs)

	scatter (row in kickoff_tsv) {
		String sample_ID = sub(basename(row[0], ".bam"), "alignSort", '')
		call TCR_Analysis {
			input:
				bucket_slash=bucket_slash,
				output_path_slash=output_path_slash,
				BAM=row[0],
				sample_ID=sample_ID,
				reference=row[1],
				barcode_list=row[2],
				docker_image=docker_image,
				number_cpu_threads=number_cpu_threads,
				boot_disk_size_GB=boot_disk_size_GB,
				disks=disks,
				task_memory_GB=task_memory_GB,
				preemptible=preemptible,
				zones=zones
			# output:
			#	String outputs
		}
	}

	output {
		Array[String] outputs = TCR_Analysis.output_path
	}
}

task TCR_Analysis {
	input {
		String bucket_slash
		String output_path_slash
		File BAM
		String sample_ID
		String reference
		File barcode_list
		String docker_image
		Int number_cpu_threads
		Int boot_disk_size_GB
		String disks
		String task_memory_GB
		Int preemptible
		String zones
	}
	
	command <<<
		set -e
		export TMPDIR=/tmp

		mkdir -v /~{sample_ID}/
		printf "~{BAM}\t~{reference}\t~{barcode_list}" > /~{sample_ID}/kickoff.tsv
		
		SeqWellTCRAnalysis /~{sample_ID}/kickoff.tsv ~{number_cpu_threads}
		
		cd /~{sample_ID}/
		rm -r ./*/
		gsutil -m mv ./* ~{bucket_slash}~{output_path_slash}~{sample_ID}/
	>>>
	output {
		String output_path = bucket_slash+output_path_slash+sample_ID+'/'
	}
	runtime { 
		docker: "~{docker_image}"
		preemptible: preemptible
		memory: "~{task_memory_GB}G"
		zones: "~{zones}"
		disks: "~{disks}"
		cpu: number_cpu_threads
		bootDiskSizeGb: boot_disk_size_GB
	}
}