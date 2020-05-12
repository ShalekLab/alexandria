# Kallisto-Bustools Reference subworkflow (https://github.com/ShalekLab/kallisto-bustools_workflow)
# A publicly available WDL workflow made by Shalek Lab for Kallisto and Bustools wrapped within kb_python
# Workflow by jgatter [at] broadinstitute.org, created November 2019. Jointly maintained with Cumulus Team.
# FULL DISCLOSURE: many optional parameters remain untested, post on GitHub with bug reports, etc.
# Kallisto and Bustools software made by Pachter Lab. Documentation: https://www.kallistobus.tools/kb_getting_started.html
# -----------------------------------------------------------------------------------------------------------
# REFERENCE INSTRUCTIONS: (1) Build or (2) download a transcriptome index
# Set run_build_reference to true, runs only one time, not for the number of samples in your sample sheet.
# Option 1) Build a transcriptome index from reference GTF and FASTA (use_lamanno=true for RNA velocity):
# 	ex: kb ref --verbose (--lamanno) -I index.idx -g transcripts_to_genes.txt -f1 cDNA.fa Mus_musculus.GRCm38.dna.primary_assembly.fa Mus_musculus.GRCm38.98.gtf
# 	Inputs: reference GTF and genomic FASTA, set use_lamanno to true if you want to run RNA velocity
# OR Option 2) Download a pre-built transcriptome index (use_lamanno=true for RNA velocity):
# 	ex: kb ref --verbose (--lamanno) -d mouse -i index.idx -g transcripts_to_genes.txt
# 	Inputs: download_index (“human”, “mouse”, “linnarsson”), use_lamanno=true if you want to run RNA velocity
# Outputs: Kallisto index, T2G mapping, cDNA FASTA, (if use_lamanno==true: intron FASTA, cDNA_transcripts_to_genes.txt, and intron_transcripts_to_genes.txt)
# -----------------------------------------------------------------------------------------------------------
# SNAPSHOT 1
# Public release.
# -----------------------------------------------------------------------------------------------------------
# SNAPSHOT 2
# Removed failOnStdErr runtime parameter.
# build_reference now creates ref within /cromwell_root rather than the home directory
# gsutil rsync copies out the files rather than gsutil mv
# preemptible has been set as 2 by default
# Several runtime parameter changes
# -----------------------------------------------------------------------------------------------------------

version 1.0

workflow kallisto_bustools_reference {
	input {
		String docker = "shaleklab/kallisto-bustools:0.24.4"
		Int number_cpu_threads = 32
		Int task_memory_GB = 128
		Int preemptible = 2
		String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
		String disks = "local-disk 256 SSD"
		Int boot_disk_size_GB = 10

		String bucket
		String output_path

		String? download_index
		File? genomic_fasta
		File? reference_gtf
		Boolean use_lamanno
	}
	String bucket_slash = sub(bucket, "/+$", '') + '/'
	String output_path_slash = if output_path == '' then '' else sub(output_path, "/+$", '') + '/'
	String base_output_path_slash = sub(output_path_slash, bucket_slash, '')

	call build_reference {
		input:
			docker=docker,
			number_cpu_threads=number_cpu_threads,
			task_memory_GB=task_memory_GB,
			preemptible=preemptible,
			zones=zones,
			disks=disks,
			boot_disk_size_GB=boot_disk_size_GB,
			bucket_slash=bucket_slash,
			output_path_slash=base_output_path_slash,
			genomic_fasta=genomic_fasta,
			reference_gtf=reference_gtf,
			download_index=download_index,
			use_lamanno=use_lamanno
	}
	output {
		File index = build_reference.index
		File T2G_mapping = build_reference.T2G_mapping
		File? cDNA_fasta = build_reference.cDNA_fasta
		File? intron_fasta = build_reference.intron_fasta
		File? cDNA_transcripts_to_capture = build_reference.cDNA_transcripts_to_capture
		File? intron_transcripts_to_capture = build_reference.intron_transcripts_to_capture
		String ref_output_path = build_reference.ref_output_path
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
		Int boot_disk_size_GB

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

		df -h /
		df -h /cromwell_root
	
		mkdir ref && cd ref
		kb ref --verbose \
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
		
		gsutil -m rsync -r . ~{bucket_slash}~{output_path_slash}ref
	}
	output {
		String index = "~{bucket_slash}~{output_path_slash}ref/index.idx"
		String T2G_mapping = "~{bucket_slash}~{output_path_slash}ref/transcripts_to_genes.txt"
		String? cDNA_fasta = "~{bucket_slash}~{output_path_slash}ref/cDNA.fa"
		String? intron_fasta = "~{bucket_slash}~{output_path_slash}ref/intron.fa"
		String? cDNA_transcripts_to_capture = "~{bucket_slash}~{output_path_slash}ref/cDNA_transcripts_to_capture.txt"
		String? intron_transcripts_to_capture = "~{bucket_slash}~{output_path_slash}ref/intron_transcripts_to_capture.txt"
		String ref_output_path = "~{bucket_slash}~{output_path_slash}ref/"
	}
	runtime {
		docker: "~{docker}"
		preemptible: preemptible
		memory: "~{task_memory_GB}G"
		zones: "~{zones}"
		disks: "~{disks}"
		cpu: number_cpu_threads
		bootDiskSizeGb: boot_disk_size_GB
	}
}