process LIMA_EITHER_END {
    tag "${meta.pool_ID}"

    input:
    tuple val(meta), path(bam), path(i7_barcode), path(i5_barcode)

    output:
    tuple val(meta), path('demux_either_i7_i5/*--*.bam'), emit: bam
    tuple val(meta), path("demux_either_i7_i5/*lima.counts"), emit: counts
    tuple val(meta), path("demux_either_i7_i5/*lima.summary"), emit: summary
    tuple val(meta), path("demux_either_i7_i5/*unbarcoded.bam"), emit: bam_unbarcoded

    script:
    """
    cat ${i7_barcode} ${i5_barcode} > barcode.fa

    mkdir -p demux_either_i7_i5

    lima \\
        --single-side \\
        -j 128 \\
        --peek-guess \\
        --ccs \\
        --min-score 26 \\
        --store-unbarcoded \\
        --split-named \\
        --log-level INFO \\
        --log-file demux_either_i7_i5/${meta.pool_ID}.lima.log \\
        ${bam} \\
        barcode.fa \\
        demux_either_i7_i5/${meta.pool_ID}.bam

    mv demux_either_i7_i5/${meta.pool_ID}.lima.counts demux_either_i7_i5/i7_5_${meta.pool_ID}.lima.counts
    mv demux_either_i7_i5/${meta.pool_ID}.lima.summary demux_either_i7_i5/i7_5_${meta.pool_ID}.lima.summary
    """
}
