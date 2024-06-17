#!/bin/bash


samplesheet="samplesheet.csv"


nextflow run \
nextflow-pacbio-demux-bbduk-summary/pacbio_demux_bbduk_DSL2.nf \
-c nextflow-pacbio-demux-bbduk-summary/nextflow.config \
--samplesheet $samplesheet \
-bg -resume
