process REMOVE_HYBRIDS {
    container 'longplexpy'
    
    publishDir path: "${params.outdir}/${sample_id}/lima_out/filtered_bam_from_both_ends", mode: 'copy'

    input:
        tuple val(sample_id), path(i5_i7_unbarcoded)
        path(hybrid_list)

    output:
        path("${sample_id}.unbarcoded.filtered.bam"), emit: filtered_bam
    
    script:
    """
    java \
        -jar /opt/picard.jar \
        FilterSamReads \
        I=${i5_i7_unbarcoded} \
        O=${sample_id}.unbarcoded.filtered.bam \
        READ_LIST_FILE=${hybrid_list} \
        FILTER=excludeReadList \
        VALIDATION_STRINGENCY=LENIENT
    """
}
