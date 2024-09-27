---
output:
  word_document: default
  html_document: default
---

# seqWell LongPlex Demultiplex Nextflow Pipeline

This is the nextflow pipeline to demultiplex PacBio data for the seqWell LongPlex Long Fragment Multiplexing kit. The pipeline uses Lima for demultiplexing and uses longplexpy tools for data filtering.  The workflow is as shown in the image below. The workflow starts with hifi bam file(s), then a two-step Lima process is conducted. Each Lima process will clip off the corresponding barcode.

 - The first Lima demulitplex uses the neighbor option to get reads with both i7 and i5 seqWell barcodes. Unbarcoded reads are then used in the next clean and Lima process.
 - From the unbarcoded reads from the first Lima process, longplexpy tool is used to remove undesired hybrids.
 - The second Lima demultiplex process uses i7 OR i5 barcode on the cleaned unbarcoded reads. 

After the two-step lima process, bam files from these two steps are merged from each sample, and fastq files are also created for each sample from the merged bam files. 
The output from this pipeline has lima output, demultiplex summary, and a fastqc report for the merged bams for each sample.

![Fig1. demultiplex workflow](./assets/demux_workflow.png)



## Docker container used in this pipeline:
 - *longplex_demux*: seqwell/longplex_demux:latest


## How to run the pipeline:
Download the code files and put the files in your working directory like this tree structure. Use `chmod +x bin/*` to make create_demux_summary.R executable.

```
$ tree
.
├── README.md
├── assets
│   └── demux_workflow.png
├── barcode
│   ├── LongPlex_set1_i5_trimmed_adapters.fa
│   ├── LongPlex_set1_i7_trimmed_adapters.fa
│   ├── LongPlex_set2_i5_trimmed_adapters.fa
│   ├── LongPlex_set2_i7_trimmed_adapters.fa
│   ├── LongPlex_set3_i5_trimmed_adapters.fa
│   └── LongPlex_set3_i7_trimmed_adapters.fa
├── data
│   └── example.bam
├── nextflow-pacbio-demux
│   ├── bin
│   │   └── create_demux_summary.R
│   ├── modules
│   │   ├── demux_stats.nf
│   │   ├── fastqc.nf
│   │   ├── lima_i7_i5_both_end.nf
│   │   ├── lima_i7_i5_either_end.nf
│   │   ├── listHybrids.nf
│   │   ├── merge_reads.nf
│   │   ├── multiqc.nf
│   │   └── removeHybrids.nf
│   ├── nextflow.config
│   ├── nextflow_schema.json
│   └── pacbio_demux.nf
├── nextflow.sh
└── samplesheet
    └── samplesheet.csv
```
The pipeline can be run using the scripts in the nextflow.sh script, run as `bash nextflow.sh`.
The required inputs are *samplesheet* and *outdir*. If you have downloaded this repo, you can run a quick test by using the *nextflow.sh* code as shown below.

```
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

```


## samplesheet requirement: 
The samplesheet is in csv format. There are four columns for the samplesheet: sample_ID, sample_path, i7_barcode, and i5_barcode.

 - *sample_ID*: You can have only letters and numbers in sampe_ID. Please avoid having underline(_) and dash (-) and dot(.) in the sample_ID.
 - *sample_path*: The sample_path can be local or a link to an s3 bucket. If it is a link to an s3 bucket, please make sure to fill in the correct credentials in the nextflow.config file.
 - *i7_barcode, i5_barcode*: The barcodes are in the barcode folder. For early access users, please use barcode set3. Please use barcode set1 if you bought the kits after the launch.

## outdir requirement:
The outdir can be local (an absolute path or a relative path) or a link to an s3 bucket. If it is a link to an s3 bucket, please make sure to fill in the correct credentials in the nextflow.config file.

## profile options: 
 - aws
 - singularity
 - apptainer
   
Profile option can be changed in the *nextflow.sh* file.


## output from example run:
 - you can find the demultiplex summary in the demux_summary folder.
 - check the README file in the output folder for the output structure.

