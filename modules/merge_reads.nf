process MERGE_READS {
    tag "${meta.sample_ID}.${well_id}"
    publishDir path: "${params.output}/${meta.sample_id}/merged_fastq", pattern: '*.fastq.gz', mode: 'copy'
    publishDir path: "${params.output}/${meta.sample_id}/merged_bam", pattern: '*.bam', mode: 'copy'

    input:
    tuple val(meta), val(well_id), path(bams)

    output:
    tuple val(meta), val(well_id), path("*.fastq.gz"), emit: fastq
    tuple val(meta), val(well_id), path("*.bam"), emit: bam

    script:
    // TODO: do a more simple merge...
    // TODO: why not output an unmapped BAM?
    """
    samtools merge ${meta.sample_ID}.${well_id}.bam ${bams}
    samtools fastq ${meta.sample_ID}.${well_id}.bam | bgzip -c > ${meta.sample_ID}.${well_id}.fastq.gz
    """
}
