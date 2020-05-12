# A publicly available WDL workflow jointly made by MIT's Love Lab and Shalek Lab for the TCR Pipeline
# Workflow By jggatter, andytu, and wadswohm [at] mit.edu, created January 2020
# FULL DISCLOSURE: many configurations remain untested, post an issue on our Github with bug reports or feature requests
# TCR Pipeline made by the andytu [at] mit.edu of Love Lab at the Koch Institute
# TCR Pipeline documentation: https://github.com/jggatter/SeqWell-TCR/tree/master/Seqwell_TCR_processing
# ------------------------------------------------------------------------------------------------------------------------------------------
# SNAPSHOT 2
# RELEASE
# ------------------------------------------------------------------------------------------------------------------------------------------
# SNAPSHOT 3
# Added FASTQ->BAM script
# ------------------------------------------------------------------------------------------------------------------------------------------
version 1.0

workflow SeqWellTCR {
	input {		
		String bucket
		String output_path
		
		Boolean isFASTQ

		# TSV containing for the following columns:
		# Sample	Species	Data
		# FASTQ_SAMPLE	[String reference: "human", "mouse"]	[gs://bucket/path/to/fastq]
		# BAM_SAMPLE	[String reference: "human", "mouse"]	[gs://bucket/path/to/bam;gs://bucket/path/to/barcodes]
		# Each row will be scattered.
		File sample_sheet

		# VM & MACHINE SETTINGS
		#String docker = "shaleklab/seqwelltcr:1.1" #"mitlovelab/seqwelltcranalysis:v1.0"
		String docker = "mitlovelab/seqwelltcranalysis:v1.1"
		Int boot_disk_size_GB = 10 #100
		Int preemptible = 2
		String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
	}
	String bucket_slash = sub(bucket, '/+$', '') + '/'
	String output_path_slash = sub(sub(output_path, '/+$', '')+'/', bucket_slash, '')

	scatter (entry in read_objects(sample_sheet)) {
		String sample_name = sub(entry.Sample, '/+$', '')
		if (isFASTQ) {
			call FASTQtoBAM as F2B {
				input:
					bucket_slash=bucket_slash,
					output_path_slash=output_path_slash,
					sample_name=sample_name,
					FASTQ=entry.Data,
					species=entry.Species,
					zones=zones,
					preemptible=preemptible,
					docker=docker,
					boot_disk_size_GB=boot_disk_size_GB
			}
		}
		call SeqWellTCRAnalysis {
			input:
				bucket_slash=bucket_slash,
				output_path_slash=output_path_slash,
				sample_name=sample_name,
				species=entry.Species,
				BAM=select_first([F2B.BAM, entry.Data]),
				barcode_list=select_first([F2B.barcode_list, entry.Data]),
				doSplit=!isFASTQ,
				docker=docker,
				preemptible=preemptible,
				zones=zones,
				boot_disk_size_GB=boot_disk_size_GB
		}
	}
	output {
		Array[String] output_paths = SeqWellTCRAnalysis.output_path
	}
}

task FASTQtoBAM {
	input {
		String bucket_slash
		String output_path_slash
		File FASTQ
		String sample_name
		String species
		
		String docker
		Int preemptible
		String zones
		Int boot_disk_size_GB

		Int cpu_threads = 16
		String disks = "local-disk 256 HDD" 
		Int task_memory_GB = 32
	}
	command <<<
		set -euo pipefail
		
		mkdir -p ~{sample_name}/F2B && cd ~{sample_name}/F2B
		/TCRAnalysis/bin/FASTQtoBAM.sh ~{FASTQ} ~{sample_name} ~{species}

		gsutil -m rsync . ~{bucket_slash}~{output_path_slash}~{sample_name}/F2B
	>>>
	output {
		File BAM = "/cromwell_root/~{sample_name}/F2B/~{sample_name}_TCRalignSort.bam"
		File barcode_list = "/cromwell_root/~{sample_name}/F2B/~{sample_name}_BCSeq.txt"
	}
	runtime {
		docker: "~{docker}"
		preemptible: preemptible
		memory: "~{task_memory_GB}G"
		zones: "~{zones}"
		disks: "~{disks}"
		cpu: cpu_threads
		bootDiskSizeGb: boot_disk_size_GB
	}
}

task SeqWellTCRAnalysis {
	input {
		String bucket_slash
		String output_path_slash
		String sample_name
		String species
		String BAM
		String barcode_list
		Boolean doSplit

		String docker
		Int preemptible
		String zones
		Int boot_disk_size_GB

		Int cpu_threads = 32
		String disks = "local-disk 128 HDD"
		Int task_memory_GB = 32 #128
	}
	command <<<
		set -e
		export TMPDIR=/tmp
		
		if [[ "~{doSplit}" == "true" ]]; then
			IFS=';' read -ra bam_barcodes <<< "~{BAM}"
			BAM="${bam_barcodes[0]}"
			barcode_list="${bam_barcodes[1]}"
		else
			BAM="~{BAM}"
			barcode_list="~{barcode_list}"
		fi
		echo $BAM && echo $barcode_list
		
		mkdir /~{sample_name}/ && cd /~{sample_name}/
		gsutil -m cp $BAM .
		gsutil -m cp $barcode_list .
		BAM="$(realpath $(basename $BAM))"
		barcode_list="$(realpath $(basename $barcode_list))"
		
		ls
		echo $BAM && echo $barcode_list

		printf "${BAM}\t~{species}\t${barcode_list}" > /~{sample_name}/kickoff.tsv
		SeqWellTCRAnalysis /~{sample_name}/kickoff.tsv ~{cpu_threads}
		
		rm -r /~{sample_name}/*/
		gsutil -m rsync -r /~{sample_name} ~{bucket_slash}~{output_path_slash}~{sample_name}
	>>>
	output {
		String output_path = bucket_slash+output_path_slash+sample_name+'/'
	}
	runtime { 
		docker: "~{docker}"
		preemptible: preemptible
		memory: "~{task_memory_GB}G"
		zones: "~{zones}"
		disks: "~{disks}"
		cpu: cpu_threads
		bootDiskSizeGb: boot_disk_size_GB
	}
}