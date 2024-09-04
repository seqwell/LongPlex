#!/bin/bash

samplesheet=samplesheet/samplesheet.csv
outdir="output/LongPlex_demux_out"

nextflow run \
-profile aws \
nextflow-pacbio-demux/pacbio_demux.nf \
-c nextflow-pacbio-demux/nextflow.config \
--samplesheet $samplesheet \
--outdir  $outdir \
-with-report \
-with-trace  \
-bg -resume
