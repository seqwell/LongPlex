process MERGE_READS {
    tag "${meta.pool_ID}.${meta.well_ID}"

    input:
    tuple val(meta), path(bams)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: fastq
    tuple val(meta), path("*.bam"), emit: bam

    script:
    // TODO: do a more simple merge...
    // TODO: why not output an unmapped BAM?
    """
    samtools merge -@ ${task.cpus} ${meta.pool_ID}.${meta.well_ID}.bam ${bams}
    samtools fastq -@ ${task.cpus} ${meta.pool_ID}.${meta.well_ID}.bam | bgzip -c > ${meta.pool_ID}.${meta.well_ID}.fastq.gz
    """
}
