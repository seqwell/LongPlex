process MERGE_READS {
    tag "${meta.sample_ID}.${meta.well_ID}"
    publishDir path: "${params.output}/${meta.sample_ID}/merged_fastq", pattern: '*.fastq.gz', mode: 'copy'
    publishDir path: "${params.output}/${meta.sample_ID}/merged_bam", pattern: '*.bam', mode: 'copy'

    input:
    tuple val(meta), path(bams)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: fastq
    tuple val(meta), path("*.bam"), emit: bam

    script:
    // TODO: do a more simple merge...
    // TODO: why not output an unmapped BAM?
    """
    samtools merge ${meta.sample_ID}.${meta.well_ID}.bam ${bams}
    samtools fastq ${meta.sample_ID}.${meta.well_ID}.bam | bgzip -c > ${meta.sample_ID}.${meta.well_ID}.fastq.gz
    """
}
