#!/bin/bash


samplesheet="samplesheet/samplesheet.csv"
outdir="output/LongPlex_demux_out"

nextflow run \
-profile singularity \
nextflow-pacbio-demux-bbduk-summary/pacbio_demux_bbduk.nf \
-c nextflow-pacbio-demux-bbduk-summary/nextflow.config \
--samplesheet $samplesheet \
--outdir  $outdir \
-with-report \
-with-trace  \
-bg -resume
