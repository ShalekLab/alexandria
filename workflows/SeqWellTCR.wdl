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
		
		Boolean is_FASTQ

		File sample_sheet
		# Tab-delimited text file.
		# Each row will be scattered. Example:
		# Sample	Species	Data	Barcodes
		# FASTQ_SAMPLE	[String reference: "human", "mouse", "macfas"]	[gs://bucket/path/to/fastq]	[gs://bucket/path/to/barcodes]
		# BAM_SAMPLE	[String reference: "human", "mouse", "macfas"]	[gs://bucket/path/to/bam]	[gs://bucket/path/to/barcodes]
		# (and so on...)

		# VM & MACHINE SETTINGS
		String docker = "shaleklab/seqwelltcr:1.1"
		#String docker = "mitlovelab/seqwelltcranalysis:v1.1"
		Int boot_disk_size_GB = 100
		Int preemptible = 2
		String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
	}
	String bucket_slash = sub(bucket, '/+$', '') + '/'
	String output_path_slash = sub(sub(output_path, '/+$', '')+'/', bucket_slash, '')

	scatter (entry in read_objects(sample_sheet)) {
		String sample_name = sub(entry.Sample, '/+$', '')
		if (is_FASTQ) {
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
		call Analysis {
			input:
				bucket_slash=bucket_slash,
				output_path_slash=output_path_slash,
				sample_name=sample_name,
				species=entry.Species,
				BAM=select_first([F2B.BAM, entry.Data]),
				barcodes_list=entry.Barcodes,
				docker=docker,
				preemptible=preemptible,
				zones=zones,
				boot_disk_size_GB=boot_disk_size_GB
		}
	}
	output {
		Array[String] output_paths = Analysis.output_path
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

task Analysis {
	input {
		String bucket_slash
		String output_path_slash
		String sample_name
		String species
		File BAM
		File barcodes_list

		Int BCcutoff = 10
		Int UMIcutoff = 10
		Int UMIlim = 1000
		Float VFreqCutoff = 0.6
		Float JFreqCutoff = 0.6
		File? mouseRef
		File? humanRef
		File? macfasRef
		File? mouseCDR3Base
		File? humanCDR3Base
		File? macfasCDR3Base
		File? humanUTRcRef

		String docker
		Int preemptible
		String zones
		Int boot_disk_size_GB

		Int cpu_threads = 32
		String disks = "local-disk 1000 HDD"
		Int task_memory_GB = 128
	}
	command <<<
		set -euo pipefail
		export TMPDIR=/tmp
		
		echo Generating TCRSettings.txt
		cat <<- SETTINGS > TCRsettings.txt
		BCcutoff	~{BCcutoff}
		UMIcutoff	~{UMIcutoff}
		UMIlim	~{UMIlim}
		VFreqCutoff	~{VFreqCutoff}
		JFreqCutoff	~{JFreqCutoff}
		mouseRef	~{default="/TCRAnalysis/bin/mouseTCR_Ctrunc_TRJ_UTR_1allele.fa" mouseRef}
		humanRef	~{default="/TCRAnalysis/bin/humanTCR_Ctrunc_TRJ_UTR_1allele.fa" humanRef}
		macfasRef	~{default="/TCRAnalysis/bin/CynoTCRv3.fa" macfasRef}
		mouseCDR3Base	~{default="/TCRAnalysis/bin/MouseCDR3bases.txt" mouseCDR3Base}
		humanCDR3Base	~{default="/TCRAnalysis/bin/HumanCDR3bases.txt" humanCDR3Base}
		macfasCDR3Base	~{default="/TCRAnalysis/bin/macFasCDR3bases_v3.txt" macfasCDR3Base}
		humanUTRcRef	~{default="/TCRAnalysis/bin/upstream_hTRBC.fa" humanUTRcRef}
		SETTINGS
		cp TCRsettings.txt /TCRAnalysis/bin/TCRsettings.txt
		cat /TCRAnalysis/bin/TCRsettings.txt # DEBUG

		echo Indexing ~{BAM}
		cd $(dirname ~{BAM})
		samtools index ~{BAM}
		ls -1 # DEBUG

		mkdir /~{sample_name}/ && cd /~{sample_name}/
		printf "~{BAM}\t~{species}\t~{barcodes_list}" > kickoff.tsv
		
		SeqWellTCRAnalysis kickoff.tsv ~{cpu_threads}
		
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