process LIST_HYBRIDS {
    tag "${meta.sample_ID}"

    input:
    tuple val(meta), path(i5_i7_report)

    output:
    path("${meta.sample_ID}.hybrid_list.txt"), emit: hybrids

    script:
    """
    longplexpy \\
        list-undesired-hybrids \\
        -l ${i5_i7_report} \\
        -o ${meta.sample_ID}.hybrid_list.txt \\
        -r "/ccs"
    """
}
