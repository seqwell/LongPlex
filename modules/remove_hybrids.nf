process REMOVE_HYBRIDS {
    tag "${meta.sample_ID}"
    publishDir path: "${output_path}/${meta.sample_ID}/hybrids/", pattern: '*.bam', mode: 'copy'

    input:
    tuple val(meta), path(i5_i7_unbarcoded)
    path(hybrid_list)
    path(output_path)

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
