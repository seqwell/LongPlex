
process lima_both_end {

tag "${sample_id}"

publishDir path: "${params.outdir}/${sample_id}/lima_out/", pattern: 'demux_*/*', mode: 'copy'

input:
tuple val(sample_id), path(bam), path(barcode1), path(barcode2)

output:

path ('demux_i7_i5/*')
tuple val(sample_id), path ('demux_i7_i5/*--*.bam')                       , emit: i7_i5_bam
tuple val(sample_id), path ("demux_i7_i5/*lima.counts")                   , emit: i7_i5_lima_count
tuple val(sample_id), path ("demux_i7_i5/*lima.summary")                  , emit: i7_i5_lima_summary
tuple val(sample_id), path ("demux_i7_i5/*lima.report")                   , emit: i7_i5_lima_report
tuple val(sample_id), path ("demux_i7_i5/*unbarcoded.bam")                , emit: unbarcoded

"""

cat $barcode1 $barcode2 | paste - -  | sort |  tr '\t' '\n' > barcode_neighbor.fa

mkdir -p demux_i7_i5
lima --neighbors  -j 128 --peek-guess  --ccs --min-score 26 \
--store-unbarcoded \
--split-named --log-level INFO \
--log-file demux_i7_i5/${sample_id}.lima.log \
${bam} \
barcode_neighbor.fa \
demux_i7_i5/${sample_id}.bam
mv demux_i7_i5/${sample_id}.lima.counts demux_i7_i5/i7_i5_${sample_id}.lima.counts 
mv demux_i7_i5/${sample_id}.lima.summary demux_i7_i5/i7_i5_${sample_id}.lima.summary 

"""
}

