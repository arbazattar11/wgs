#!/bin/bash

# Variables
SAMPLE_NAME="sample_name"
FASTQ_DIR="/path/to/fastq"
OUTPUT_DIR="/path/to/output"
REF_GENOME="/path/to/reference/genome.fasta"
BWA="/path/to/bwa"
GATK="/path/to/gatk"
THREADS=8

# Create necessary directories
mkdir -p ${OUTPUT_DIR}/fastqc
mkdir -p ${OUTPUT_DIR}/alignment
mkdir -p ${OUTPUT_DIR}/variants

# Step 1: Run FastQC for quality control of raw reads
fastqc ${FASTQ_DIR}/*.fastq.gz -o ${OUTPUT_DIR}/fastqc

# Step 2: Aggregate FastQC reports using MultiQC
multiqc ${OUTPUT_DIR}/fastqc -o ${OUTPUT_DIR}/fastqc

# Step 3: Index the reference genome if not already indexed
if [ ! -f ${REF_GENOME}.bwt ]; then
    ${BWA} index ${REF_GENOME}
fi

# Step 4: Align reads to the reference genome using BWA
${BWA} mem -t ${THREADS} ${REF_GENOME} ${FASTQ_DIR}/*_R1_*.fastq.gz ${FASTQ_DIR}/*_R2_*.fastq.gz > ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.sam

# Step 5: Convert SAM to BAM, sort, and index using SAMtools
samtools view -Sb ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.sam | samtools sort -o ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.sorted.bam
samtools index ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.sorted.bam

# Step 6: Mark duplicates using GATK
${GATK} MarkDuplicates -I ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.sorted.bam -O ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.dedup.bam -M ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.metrics.txt
samtools index ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.dedup.bam

# Step 7: Call variants using GATK HaplotypeCaller
${GATK} HaplotypeCaller -R ${REF_GENOME} -I ${OUTPUT_DIR}/alignment/${SAMPLE_NAME}.dedup.bam -O ${OUTPUT_DIR}/variants/${SAMPLE_NAME}.g.vcf.gz -ERC GVCF

# Step 8: Convert GVCF to VCF using GATK GenotypeGVCFs
${GATK} GenotypeGVCFs -R ${REF_GENOME} -V ${OUTPUT_DIR}/variants/${SAMPLE_NAME}.g.vcf.gz -O ${OUTPUT_DIR}/variants/${SAMPLE_NAME}.vcf.gz

# Step 9: Index the VCF file using bcftools
bcftools index ${OUTPUT_DIR}/variants/${SAMPLE_NAME}.vcf.gz

# Step 10: Filter variants using bcftools
bcftools filter -O z -o ${OUTPUT_DIR}/variants/${SAMPLE_NAME}.filtered.vcf.gz -s LOWQUAL -i '%QUAL>20 && DP>10' ${OUTPUT_DIR}/variants/${SAMPLE_NAME}.vcf.gz
bcftools index ${OUTPUT_DIR}/variants/${SAMPLE_NAME}.filtered.vcf.gz

# Summary
echo "Whole-genome sequencing analysis pipeline completed successfully."
