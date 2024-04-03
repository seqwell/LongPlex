#!/bin/bash


samples=*.bam
barcodes_i7=LongPlex_set3_i7_trimmed_adapters.fa
barcodes_i5=LongPlex_set3_i5_trimmed_adapters.fa


nextflow run \
nextflow-pacbio-demux-bbduk/pacbio_demux_bbduk.nf \
-c nextflow-pacbio-demux-bbduk/nextflow.config \
--samples $samples \
--barcodes_i7 $barcodes_i7 \
--barcodes_i5 $barcodes_i5 \
-bg -resume
