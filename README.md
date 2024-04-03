
# nextflow pipeline for pacbio lima bbduk demux

This is the work flow in nextflow pipeline using lima and bbduk to do demux on pacbio data for seqWell longplex kit. The output from this pipeline has lima output, bbduk output, and also a bbduk summary.

## Hifi bam file name requirements: 
For the hifi bam file name, it requires pacbio barcode info (for example bc1003) in the third string separated by .
For example, `SEQW102-002-01.hifi_reads.bc1003.bam` is an acceptable bam file name. `bc1003` is used as a key for this hifi bam file in the pipeline. If you have bam file name different from this pattern, please rename the file as the code is using the pattern to create lima produced files. 

## Docker containers used in this pipeline:
 - *lima*: quay.io/biocontainers/lima:2.7.1--h9ee0642_0
 - *samtools*: quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1
 - *bbtools*: staphb/bbtools:39.01
 - *R*: rocker/verse:4.3.1



## How to run the pipeline:
Download the code files and put the files in your working directory like this tree structure. Use `chmod +x bin/*` to make create_bbduk_summary.R executable.

```
$ tree
.
├── README.md
├── nextflow-pacbio-demux-bbduk
│   ├── bin
│   │   └── create_bbduk_summary.R
│   ├── nextflow.config
│   └── pacbio_demux_bbduk.nf
└── nextflow.sh
```
The pipeline can be run using the scripts in the nextflow.sh script, run as `bash nextflow.sh`.
The required inputs are hifi bam files, and seqWell LongPlex barcode.

```
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


```



