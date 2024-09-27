process REMOVE_HYBRIDS {
    tag "${meta.sample_ID}"

    input:
    tuple val(meta), path(i5_i7_unbarcoded)
    path(hybrid_list)

    output:
    tuple val(meta), path("${meta.sample_ID}.unbarcoded.filtered.bam"), emit: bam_filtered
    
    script:
    """
    picard \\
        FilterSamReads \\
        I=${i5_i7_unbarcoded} \\
        O=${meta.sample_ID}.unbarcoded.filtered.bam \\
        READ_LIST_FILE=${hybrid_list} \\
        FILTER=excludeReadList \\
        VALIDATION_STRINGENCY=LENIENT
    """
}
