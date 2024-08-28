
process merge_reads {

publishDir path: "${params.outdir}/${sample_id}/merged_fastq", pattern: '*.fastq.gz', mode: 'copy'
publishDir path: "${params.outdir}/${sample_id}/merged_bam",   pattern: '*.bam', mode: 'copy'

tag "${sample_id}_${well_id}"

input:
  tuple val(sample_id), val(well_id), path(bam) 
  

output:
  tuple val(sample_id), val(well_id), path ("*.fastq.gz") , emit: fq
  tuple val(sample_id), val(well_id), path ("*.bam") ,      emit: bam
  

"""
samtools  merge ${sample_id}.${well_id}.bam $bam
samtools fastq ${sample_id}.${well_id}.bam | bgzip -c > ${sample_id}.${well_id}.fastq.gz

"""

}                          
