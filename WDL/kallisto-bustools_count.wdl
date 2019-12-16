# Kallisto-Bustools count subworkflow
# A publicly available WDL workflow made by Shalek Lab for Kallisto and Bustools
# Workflow By jgatter [at] broadinstitute.org, created November 2019
# FULL DISCLOSURE: many optional parameters remain untested, contact me with bug reports or feature requests
# Kallisto and Bustools made by Pachter Lab. Documentation: https://www.kallistobus.tools/
# -----------------------------------------------------------------------------------------------------------

version 1.0

workflow kallisto_bustools_count {
	input {
		String docker = "shaleklab/kallisto-bustools:0.24.4"
		Int number_cpu_threads = 32
		Int task_memory_GB = 32
		Int preemptible = 2
		String zones = "us-east1-d us-west1-a us-west1-b"
		String disks = "local-disk 128 SSD"
		Int boot_disk_size_gb = 64

		String bucket
		String output_path
		File index
		File T2G_mapping
		String technology # DROPSEQ, 10XV1, 10XV2, 10XV3 or see kb --list for more
		File R1_fastq

		File? R2_fastq
		File? barcodes_whitelist
		Boolean use_lamanno=false
		File? cDNA_transcripts_to_capture
		File? intron_transcripts_to_capture
		Boolean nucleus=false
		Boolean bustools_filter=true
		Boolean loom=false
		Boolean h5ad=false
	}
	call count {
		input:
			docker=docker,
			number_cpu_threads=number_cpu_threads,
			task_memory_GB=task_memory_GB,
			preemptible=preemptible,
			zones=zones,
			disks=disks,
			boot_disk_size_gb=boot_disk_size_gb,
			bucket_slash=sub(bucket, "/+$", '') + '/',
			output_path_slash=sub(output_path, "/+$", '') + '/',
			index=index,
			T2G_mapping=T2G_mapping,
			technology=technology,
			R1_fastq=R1_fastq,
			R2_fastq=R2_fastq,
			barcodes_whitelist=barcodes_whitelist,
			use_lamanno=use_lamanno,
			cDNA_transcripts_to_capture=cDNA_transcripts_to_capture,
			intron_transcripts_to_capture=intron_transcripts_to_capture,
			nucleus=nucleus,
			bustools_filter=bustools_filter,
			loom=loom,
			h5ad=h5ad
	}
	output {
		File counts_unfiltered_matrix = count.counts_unfiltered_matrix
		File counts_filtered_matrix = count.counts_filtered_matrix
	}
}

task count {
	input {
		String docker
		Int number_cpu_threads
		Int task_memory_GB
		Int preemptible
		String zones
		String disks
		Int boot_disk_size_gb

		String bucket_slash
		String output_path_slash
		File index
		File T2G_mapping
		String technology
		File R1_fastq
		
		File? R2_fastq
		File? barcodes_whitelist
		Boolean use_lamanno
		File? cDNA_transcripts_to_capture
		File? intron_transcripts_to_capture
		Boolean nucleus
		Boolean bustools_filter
		Boolean loom
		Boolean h5ad
		Int program_memory_GB = task_memory_GB * 4 / 5
	}
	command {

		mkdir ~/kb
		kb count --verbose \
			-i ~{index} \
			-g ~{T2G_mapping} \
			-x ~{technology} \
			-o ~/kb/outputs \
			~{"-w "+barcodes_whitelist} \
			~{true="--lamanno" false='' use_lamanno} \
			~{"-c1 "+cDNA_transcripts_to_capture} \
			~{"-c2 "+intron_transcripts_to_capture} \
			~{true="--nucleus" false='' nucleus} \
			~{true="--filter bustools" false='' bustools_filter} \
			~{true="--loom" false='' loom} \
			~{true="--h5ad" false='' h5ad} \
			~{"-t "+number_cpu_threads} \
			~{"-m "+program_memory_GB+'G'} \
			~{R1_fastq} \
			~{R2_fastq}

		gsutil -m cp -r ~/kb/outputs ~{bucket_slash}~{output_path_slash}
	}
	output {
		String counts_unfiltered_matrix = "~{bucket_slash}~{output_path_slash}outputs/counts_unfiltered/cells_x_genes.mtx"
		String counts_filtered_matrix = "~{bucket_slash}~{output_path_slash}outputs/counts_filtered/cells_x_genes.mtx"
	}
	runtime {
		docker: "~{docker}"
		preemptible: preemptible
		memory: "~{task_memory_GB}G"
		zones: "~{zones}"
		bootDiskSizeGb: boot_disk_size_gb
		disks: "~{disks}"
		cpu: number_cpu_threads
	}
}