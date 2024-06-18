#!/bin/bash


samplesheet="samplesheet/samplesheet.csv"


nextflow run \
nextflow-pacbio-demux-bbduk-summary/pacbio_demux_bbduk.nf \
-c nextflow-pacbio-demux-bbduk-summary/nextflow.config \
--samplesheet $samplesheet \
-with-report \
-bg -resume
