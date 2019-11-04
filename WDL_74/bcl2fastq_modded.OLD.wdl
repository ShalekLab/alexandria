workflow dropseq_bcl2fastq {
	String input_bcl_directory
	String output_directory

	# Whether to delete input bcl directory. If false, you should delete this folder yourself so as to not incur storage charges.
	Boolean? delete_input_bcl_directory = false
	String? zones = "us-central1-b"
	Int? num_cpu = 64
	String? memory = "128G"
	Int? disk_space = 1500
	Int? preemptible = 2
	Int minimum_trimmed_read_length = 10
	Int mask_short_adapter_reads = 10
	String? bcl2fastq_version = "2.20.0.422"
	String? use_bases_mask
	String? use_bases_mask_flag = if use_bases_mask == '' then '' else "--use-bases-mask "+use_bases_mask

	call run_bcl2fastq {
		input:
			input_bcl_directory = sub(input_bcl_directory, "/+$", ""),
			output_directory = sub(output_directory, "/+$", ""),
			delete_input_bcl_directory = delete_input_bcl_directory,
			zones = zones,
			num_cpu = num_cpu,
			minimum_trimmed_read_length=minimum_trimmed_read_length,
			mask_short_adapter_reads=mask_short_adapter_reads,
			memory = memory,
			disk_space = disk_space,
			preemptible = preemptible,
			bcl2fastq_version=bcl2fastq_version,
			use_bases_mask_flag=use_bases_mask_flag
	}

	output {
		String fastqs = run_bcl2fastq.fastqs
	}
}

task run_bcl2fastq {
	String input_bcl_directory
	String output_directory
	Boolean delete_input_bcl_directory
	String zones
	Int num_cpu
	String memory
	Int disk_space
	Int preemptible
	Int minimum_trimmed_read_length
	Int mask_short_adapter_reads
	String run_id = basename(input_bcl_directory)
	String bcl2fastq_version
	String? use_bases_mask_flag


	command {
		set -e
		export TMPDIR=/tmp

		gsutil -q -m cp -r ${input_bcl_directory} .

		cd ${run_id}

		bcl2fastq \
		--output-dir out \
		--no-lane-splitting \
		--minimum-trimmed-read-length ${minimum_trimmed_read_length} \
		--mask-short-adapter-reads ${mask_short_adapter_reads} \
		${use_bases_mask_flag}

		cd out

		gsutil -q -m cp -r . ${output_directory}/${run_id}_fastqs/

		python <<CODE

		import os
		import os.path as osp
		import re
		import pandas as pd
		from subprocess import check_call
		gs_url = '${output_directory}/${run_id}_fastqs/'

		samples_found = 0
		with open('../../sample_sheet.txt', 'w') as sample_sheet_writer:
			for project_dir in os.listdir('.'):
				if not osp.isdir(osp.join(project_dir)) or project_dir == 'Reports' or project_dir == 'Stats': continue
				for sample_id_dir in os.listdir(osp.join(project_dir)):
					if not osp.isdir(osp.join(project_dir, sample_id_dir)): continue
					fastq_files = os.listdir(osp.join(project_dir, sample_id_dir))
					if len(fastq_files) != 2:
						raise ValueError(str(len(fastq_files)) + ' fastq files found')
					fastq_files.sort()
					fastq_path = gs_url + project_dir + '/' + sample_id_dir + '/'
					sample_id = re.sub('_S[0-9]+_R1_001.fastq.gz', '', fastq_files[0])
					sample_sheet_writer.write(sample_id)
					sample_sheet_writer.write('\t' + fastq_path+fastq_files[0])
					sample_sheet_writer.write('\t' + fastq_path+fastq_files[1])
					size_R1 = osp.getsize(osp.join(fastq_path.replace(gs_url, "./"), fastq_files[0]))
					size_R2 = osp.getsize(osp.join(fastq_path.replace(gs_url, "./"), fastq_files[1]))
					sample_sheet_writer.write('\t' + str(size_R1 + size_R2))
					sample_sheet_writer.write('\n')
					samples_found += 1
			# if no fastq files found, assume no project was specified in the sample sheet
			if samples_found == 0:
				files = os.listdir('.')
				for file in files:
					if not file.startswith('Undetermined_') and file.endswith('_R1_001.fastq.gz'):
						fastq_path = gs_url + '/'
						fastq_files = [file, file.replace('_R1_001.fastq.gz', '_R2_001.fastq.gz')]
						sample_id = re.sub('_S[0-9]+_R1_001.fastq.gz', '',fastq_files[0])
						sample_sheet_writer.write(sample_id)
						sample_sheet_writer.write('\t' + fastq_path + fastq_files[0])
						sample_sheet_writer.write('\t' + fastq_path + fastq_files[1])
						size_R1 = osp.getsize(osp.join(fastq_path.replace(gs_url, "./"), fastq_files[0]))
						size_R2 = osp.getsize(osp.join(fastq_path.replace(gs_url, "./"), fastq_files[1]))
						sample_sheet_writer.write('\t' + str(size_R1 + size_R2))
						sample_sheet_writer.write('\n')

		cm = pd.read_csv("../../sample_sheet.txt", dtype=str, header=["Sample", "R1_Path", "R2_Path", "CollectiveSize"])
		cm.drop(columns=["R1_Path", "R2_Path", "CollectiveSize"])
		def get_dge_location(element):
			return "${dropseq_output_directory_stripped}/"+element+'/'+element+"_dge.txt.gz"
		cm["Location"] = cm["Sample"].map(func=get_dge_location, args=(run_dropseq,))	
		cm.to_csv("count_matrix.csv", header=True, index=False)

		if '${delete_input_bcl_directory}' is 'true':
			call_args = ['gsutil', '-q', '-m', 'rm', '-r', '${input_bcl_directory}']
			check_call(call_args)
		CODE

		gsutil -q -m cp	 ../../sample_sheet.txt "${output_directory}/${run_id}_fastqs.txt"
		gsutil -q -m cp count_matrix.csv ${scCloud_output_directory_stripped}/; fi
	}

	output {
		String fastqs = "${output_directory}/${run_id}_fastqs.txt"
	}

	runtime {
		docker: "regevlab/bcl2fastq-${bcl2fastq_version}"
		zones: zones
		memory: memory
		bootDiskSizeGb: 12
		disks: "local-disk ${disk_space} HDD"
		cpu: num_cpu
		preemptible: preemptible
	}
}
