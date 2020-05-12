# scBCR_reconstruction workflow
# A publicly available WDL workflow made by Shalek Lab for reconstructing B Cell Receptor sequences via BRAPeS
# By jgatter [at] mit.edu, skazer [at] mit.edu. Snapshot published ~!!INSERT HERE!!~
# HISAT2 by Kim Lab (https://github.com/DaehwanKimLab/hisat2)
# BRAPeS by Yosef Lab (https://github.com/YosefLab/BRAPeS)
# ------------------------------------------------------------------------------------------------------------------------------------------
# SNAPSHOT 1
# Release
# ------------------------------------------------------------------------------------------------------------------------------------------

version 1.0

workflow scBCR_reconstruction {
	input {
		File sample_sheet
		String output_path
		String index
		String index_prefix

		Int preemptible = 2
		String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
		String docker = "shaleklab/scbcr:dev"
		Int boot_disk_GB = 10
	}
	String output_path_stripped = sub(output_path, "/+$", '')
	String index_stripped = sub(index, "/+$", '')

	scatter (entry in read_objects(sample_sheet)) {
		call HISAT2 {
			input:
				sample_name=entry.Sample,
				index=index_stripped,
				index_prefix=index_prefix,
				output_path_stripped=output_path_stripped,
				R1_fastq=entry.R1_Path,
				R2_fastq=entry.R2_Path,
				docker=docker,
				zones=zones,
				preemptible=preemptible,
				boot_disk_GB=boot_disk_GB
		}
	}
	call calculate_disk_size as calculate {
		input:
			sample_sizes_KB=HISAT2.sample_size_KB,
			zones=zones,
			preemptible=preemptible
	}
	call BRAPeS {
		input:
			sams=HISAT2.sam,
			output_path_stripped=output_path_stripped,
			disk_size_GB=calculate.disk_size_GB,
			zones=zones,
			docker=docker,
			preemptible=preemptible,
			boot_disk_GB=boot_disk_GB
	}
	output {
		Array[File] hisat2_summary_files = HISAT2.summary_file
		File BRAPeS_summary_file = BRAPeS.summary_file
		File BRAPeS_reconstructions_file = BRAPeS.reconstructions_file
		String output_directory = output_path_stripped+'/'
	}
}

task HISAT2 {
	input {
		String sample_name
		String output_path_stripped
		File R1_fastq
		File R2_fastq
		String index
		String index_prefix

		String zones
		Int preemptible
		String docker
		Int boot_disk_GB

		Int memory_GB = 7
		Int cpu = 4
		String disk = "local-disk 10 HDD"
	}
	command <<<
		set -euo pipefail

		if [[ "~{index}" == *".tar.gz" || "~{index}" == *".tgz" ]]; then
			echo DOWNLOADING AND DECOMPRESSING TARRED INDEX #.tar.gz or .tgz
			gsutil -q cp ~{index} .
			index="$(basename ~{index})"
			tar -xf $index index
			rm $index
		else
			echo DOWNLOADING INDEX DIRECTORY
			mkdir index
			gsutil -q -m cp ~{index}/* index/
		fi

		mkdir -p /cromwell_root/~{sample_name}
		cd /cromwell_root/~{sample_name}

		echo RUNNING HISAT2
		hisat2 -t -q -x /cromwell_root/index/~{index_prefix} \
			-1 ~{R1_fastq} \
			-2 ~{R2_fastq} \
			--summary-file hisat2_~{sample_name}.log \
			-S ~{sample_name}.sam

		echo CREATING MAPPED AND UNMAPPED BAMS FROM SAM
		samtools view -S -b -h -F4 ~{sample_name}.sam > mapped.bam
		samtools view -S -b -h -f4 ~{sample_name}.sam > unmapped.bam

		echo SORTING MAPPED AND UNMAPPED BAMS
		samtools sort mapped.bam > mapped_sorted.bam
		samtools sort unmapped.bam > unmapped_sorted.bam
		
		echo INDEXING SORTED BAMS
		samtools index mapped_sorted.bam
		samtools index unmapped_sorted.bam

		gsutil -m rsync -r /cromwell_root/~{sample_name} ~{output_path_stripped}/~{sample_name}
	>>>
	output {
		String summary_file = "~{output_path_stripped}/~{sample_name}/hisat2_~{sample_name}.log"
		String sam = "~{output_path_stripped}/~{sample_name}/~{sample_name}.sam"
		String mapped_bam = "~{output_path_stripped}/~{sample_name}/mapped.bam"
		String unmapped_bam = "~{output_path_stripped}/~{sample_name}/unmapped.bam"
		String sorted_mapped_bam = "~{output_path_stripped}/~{sample_name}/mapped_sorted.bam"
		String sorted_unmapped_bam = "~{output_path_stripped}/~{sample_name}/unmapped_sorted.bam"
		String sorted_mapped_bam_index = "~{output_path_stripped}/~{sample_name}/mapped_sorted.bam.bai"
		String sorted_unmapped_bam_index = "~{output_path_stripped}/~{sample_name}/unmapped_sorted.bam.bai"
		Int sample_size_KB = ceil(size("~{sample_name}/unmapped_sorted.bam", "KB") + size("~{sample_name}/mapped_sorted.bam", "KB") + size("~{sample_name}/unmapped_sorted.bam.bai", "KB") + size("~{sample_name}/mapped_sorted.bam.bai", "KB"))
	}
	runtime {
		docker: "~{docker}"
		zones: "~{zones}"
		preemptible: preemptible
		disks: "~{disk}"
		cpu: cpu
		memory: "~{memory_GB}G"
		bootDiskSizeGb: boot_disk_GB
	}
}

task calculate_disk_size {
	input {
		Float BRAPeS_disk_multiplier = 2
		Array[Int] sample_sizes_KB
		String zones
		Int preemptible
	}
	command <<<
		python <<CODE
		import math
		print(math.floor( ~{BRAPeS_disk_multiplier} * (~{sep="+" sample_sizes_KB}) / 1000000 + 128 ))
		CODE
	>>>
	output {
		Int disk_size_GB = read_int(stdout())
	}
	runtime {
		docker: "shaleklab/alexandria:0.2"
		zones: "~{zones}"
		preemptible: preemptible
		disks: "local-disk 10 HDD"
		cpu: 1
		memory: "2G"
	}
}

task BRAPeS {
	input {
		Array[String] sams
		String output_path_stripped
		String disk_size_GB
		String zones
		Int preemptible
		Int boot_disk_GB
		String docker

		String genome = "hg38"
		Boolean? downsample 
		Int? top # If set, recommended = 10
		Int iterations = 20 
		Int score = 15 
		String output_prefix = "out"
		Int memory_GB = 32
		Int cpu = 16
		String disk = "local-disk ~{disk_size_GB} HDD"
	}
	command <<<
		set -euo pipefail

		echo -------------------------------------------------
		echo LOCALIZING BAM AND BAI FILES
		mkdir /cromwell_root/samples
		gsutil -q -m rsync -r \
			-x ".*\.sam$|.*mapped\.bam$|.*\.log$" \
			~{output_path_stripped} \
			/cromwell_root/samples
		echo -------------------------------------------------
		echo RUNNING BRAPeS FOR EACH SAMPLE 
		python /scBCR/BRAPeS/brapes.py \
			-genome ~{genome} \
			-path /cromwell_root/samples/ \
			-bam mapped_sorted.bam \
			-unmapped unmapped_sorted.bam \
			-output BRAPeS/~{output_prefix} \
			-sumF /cromwell_root/samples/~{output_prefix} \
			~{true='-downsample' false='' downsample} \
			-iterations ~{iterations} \
			-score ~{score} \
			~{"-top "+top}
		echo -------------------------------------------------
		echo COMPLETED BRAPeS, TRANSFERRING ALL FILES TO RESIDE IN ~{output_path_stripped}
		gsutil -q -m rsync -r /cromwell_root/samples ~{output_path_stripped}
		echo -------------------------------------------------
	>>>
	output {
		String summary_file = output_path_stripped+"/samples/"+output_prefix+".summary.txt"
		String reconstructions_file = output_path_stripped+"/samples/"+output_prefix+".BCRs.txt"
	}
	runtime {
		docker: "~{docker}"
		zones: "~{zones}"
		preemptible: preemptible
		disks: "~{disk}"
		cpu: cpu
		memory: "~{memory_GB}G"
		bootDiskSizeGb: boot_disk_GB
	}
}