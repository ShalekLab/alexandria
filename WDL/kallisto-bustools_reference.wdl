# Kallisto-Bustools reference subworkflow
# A publicly available WDL workflow made by Shalek Lab for Kallisto and Bustools
# Workflow By jgatter [at] broadinstitute.org, created November 2019
# FULL DISCLOSURE: many optional parameters remain untested, contact me with bug reports or feature requests
# Kallisto and Bustools made by Pachter Lab. Documentation: https://www.kallistobus.tools/
# -----------------------------------------------------------------------------------------------------------
# SNAPSHOT 2
# Countless tweaks, still not completely functional

version 1.0

workflow kallisto_bustools_reference {
	input {
		String docker = "shaleklab/kallisto-bustools:0.24.4"
		Int number_cpu_threads = 32
		Int task_memory_GB = 64
		Int preemptible = 2
		String zones = "us-east1-d us-west1-a us-west1-b"
		String disks = "local-disk 64 SSD"

		String bucket
		String output_path

		String? download_index
		File? genomic_fasta
		File? reference_gtf
		Boolean use_lamanno = false
	}

	call build_reference {
		input:
			docker=docker,
			number_cpu_threads=number_cpu_threads,
			task_memory_GB=task_memory_GB,
			preemptible=preemptible,
			zones=zones,
			disks=disks,
			bucket_slash=sub(bucket, "/+$", '') + '/',
			output_path_slash=sub(output_path, "/+$", '') + '/',
			genomic_fasta=genomic_fasta,
			reference_gtf=reference_gtf,
			download_index=download_index,
			use_lamanno=use_lamanno
	}
	output {
		#String index = build_reference.index
		#String T2G_mapping = build_reference.T2G_mapping
		#String? cDNA_fasta = build_reference.cDNA_fasta
		#String? intron_fasta = build_reference.intron_fasta
		#String? cDNA_transcripts_to_capture = build_reference.cDNA_transcripts_to_capture
		#String? intron_transcripts_to_capture = build_reference.intron_transcripts_to_capture
		File index = build_reference.index
		File T2G_mapping = build_reference.T2G_mapping
		File? cDNA_fasta = build_reference.cDNA_fasta
		File? intron_fasta = build_reference.intron_fasta
		File? cDNA_transcripts_to_capture = build_reference.cDNA_transcripts_to_capture
		File? intron_transcripts_to_capture = build_reference.intron_transcripts_to_capture
	}
}

task build_reference {
	input {
		String docker
		Int number_cpu_threads
		Int task_memory_GB
		Int preemptible
		String zones
		String disks

		String bucket_slash
		String output_path_slash
		File? genomic_fasta
		File? reference_gtf
		String? download_index
		Boolean use_lamanno
	}
	command {
		set -e
		export TMPDIR=/tmp

		kb ref --verbose \
			--keep-tmp \
			-i index.idx \
			-g transcripts_to_genes.txt \
			-f1 cDNA.fa \
			~{"-d "+download_index} \
			~{true="--lamanno" false='' use_lamanno} \
			~{true="-f2 intron.fa" false='' use_lamanno} \
			~{true="-c1 cDNA_transcripts_to_capture.txt" false='' use_lamanno} \
			~{true="-c2 intron_transcripts_to_capture.txt" false='' use_lamanno} \
			~{genomic_fasta} \
			~{reference_gtf}

		gsutil -m cp * ~{bucket_slash}~{output_path_slash}
	}
	output {
		String index = "~{bucket_slash}~{output_path_slash}index.idx"
		String T2G_mapping = "~{bucket_slash}~{output_path_slash}transcripts_to_genes.txt"
		String? cDNA_fasta = "~{bucket_slash}~{output_path_slash}cDNA.fa"
		String? intron_fasta = "~{bucket_slash}~{output_path_slash}intron.fa"
		String? cDNA_transcripts_to_capture = "~{bucket_slash}~{output_path_slash}cDNA_transcripts_to_capture.txt"
		String? intron_transcripts_to_capture = "~{bucket_slash}~{output_path_slash}intron_transcripts_to_capture.txt"
	}
	runtime {
		docker: "~{docker}"
		preemptible: preemptible
		memory: "~{task_memory_GB}G"
		zones: "~{zones}"
		disks: "~{disks}"
		cpu: number_cpu_threads
	}
}