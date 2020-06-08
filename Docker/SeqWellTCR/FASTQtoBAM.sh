#!/bin/bash

#The goal of the script is to first transform the Read-1-index-1 format to Read-1-Read-2 format. that way, the TCR CDR3
#sequence should be in Read 1, and the associated cell barcode/UMI should be in Read 2.
#Then, the resulting pair of Fastqs are mapped to TCR reference (via bwa) to filter for reads that map (anywhere) on the TCR
#loci (the referecne is a collection of all VDJ and C genes). The final output is a bam file, which will then be used for subsequent processing. 
#Please see submission syntax example below for how to kick off this script in via bash.

# First variable is the sequence we put in. Second one is the sample name.
# Ex: ./FASTQtoBAM.sh fastq sampleA mouse

sequence="$1"
sample="$2"
species="$3"

set -euo pipefail

echo Generating ${sample}_IndexReads.txt
awk 'NR%4==2' "${sequence}" \
	| rev \
	| tr ATCG TAGC \
	> "${sample}_IndexReads.txt"

echo Generating ${sample}_QSeq.txt
awk 'NR%4==0' "${sequence}" > "${sample}_QSeq.txt"

echo Generating ${sample}_BCSeq.txt
awk 'NR%4==1' "${sequence}" \
	| grep -o "[ATCGN]*" \
	> "${sample}_BCSeq.txt"

echo Generating ${sample}_QRead2.txt
sed 's~[ATGCN]~@~g' "${sample}_BCSeq.txt" > "${sample}_QRead2.txt"

echo Generating ${sample}_seqHeaders.txt
awk 'NR%4==1' "${sequence}" \
	| grep -o "^.*#" \
	> "${sample}_seqHeaders.txt" 
echo Generating ${sample}_seqHeadersRead1.txt
sed 's~#~#/1~' "${sample}_seqHeaders.txt" > "${sample}_seqHeadersRead1.txt"

echo Generating ${sample}_seqHeadersRead2.txt
sed 's~#~#/2~' "${sample}_seqHeaders.txt" > "${sample}_seqHeadersRead2.txt"

echo Generating ${sample}_qualHeadersRead2.txt
sed 's~@~+~' "${sample}_seqHeadersRead2.txt" > "${sample}_qualHeadersRead2.txt"

echo Generating ${sample}_qualHeadersRead1.txt
sed 's~@~+~' "${sample}_seqHeadersRead1.txt" > "${sample}_qualHeadersRead1.txt"

echo Generating ${sample}_TCRreadFinal.fastq
paste -d '\n' \
	"${sample}_seqHeadersRead2.txt" \
	"${sample}_IndexReads.txt" \
	"${sample}_qualHeadersRead2.txt" \
	"${sample}_QSeq.txt" \
	> "${sample}_TCRreadFinal.fastq"

echo Generating ${sample}_Read1.fastq
paste -d '\n' \
	"${sample}_seqHeadersRead1.txt" \
	"${sample}_BCSeq.txt" \
	"${sample}_qualHeadersRead1.txt" \
	"${sample}_QRead2.txt" \
	> "${sample}_Read1.fastq"

if [[ "${species}" == "macfas" ]]; then
	fasta="CynoTCRv3.fa"
else
	fasta="${species}TCR.fa"
fi

echo Running bwa mem with FASTA=${fasta} to generate ${sample}_TCRalign.sam
/bwa/bwa mem /TCRAnalysis/bin/${fasta} \
	${sample}_Read1.fastq \
	${sample}_TCRreadFinal.fastq \
| /samtools/samtools view -hF 256 > ${sample}_TCRalign.sam

/samtools/samtools sort -o ${sample}_TCRalignSort.bam ${sample}_TCRalign.sam
/samtools/samtools index ${sample}_TCRalignSort.bam