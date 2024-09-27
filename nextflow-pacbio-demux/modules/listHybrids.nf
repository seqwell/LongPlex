process LIST_HYBRIDS {
    container 'longplexpy'
    publishDir path: "${params.outdir}/${sample_id}/hybrid_list", mode: 'copy'
    
    input:
        tuple val(sample_id), path(i5_i7_report)
    output:
        path("${sample_id}.hybrid_list.txt"), emit: hybrid_list

    script:
    """
    longplexpy \
        list-undesired-hybrids \
        -l ${i5_i7_report} \
        -o ${sample_id}.hybrid_list.txt \
        -r "/ccs"
    """

}
