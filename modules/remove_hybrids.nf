process REMOVE_HYBRIDS {
    tag "${meta.sample_ID}"

    input:
    tuple val(meta), path(i5_i7_unbarcoded), path(i7_barcode), path(i5_barcode)
    path(hybrid_list)

    output:
    tuple val(meta), path("${meta.sample_ID}.unbarcoded.filtered.bam"), path(i7_barcode), path(i5_barcode), emit: bam_filtered_and_barcodes
    
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
