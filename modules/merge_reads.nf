process MERGE_READS {
    tag "${meta.pool_ID}.${meta.well_ID}"

    input:
    tuple val(meta), path(bams)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: fastq
    tuple val(meta), path("*.bam"), emit: bam
    tuple val(meta), path("*.bam*"), emit: bam_w_index

    script:
    def id  = meta.sample_ID
    def tag = "${meta.pool_ID}_${meta.sample_ID}"
    """
    samtools merge -@ ${task.cpus} ${id}.bam ${bams}

    pbindex ${id}.bam
    samtools index ${id}.bam
    samtools fastq -@ ${task.cpus} ${id}.bam | bgzip -c > ${id}.fastq.gz
    """
}



