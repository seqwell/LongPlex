process LIMA_BOTH_END {
    tag "${meta.sample_ID}"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path('demux_i7_i5/*--*.bam'), emit: bam
    tuple val(meta), path("demux_i7_i5/*lima.counts"), emit: counts
    tuple val(meta), path("demux_i7_i5/*lima.summary"), emit: summary
    tuple val(meta), path("demux_i7_i5/*lima.report"), emit: report
    tuple val(meta), path("demux_i7_i5/*unbarcoded.bam"), emit: bam_unbarcoded

    script:
    """
    cat ${meta.i7_barcode} ${meta.i5_barcode} | paste - -  | sort |  tr '\\t' '\\n' > barcode_neighbor.fa

    mkdir -p demux_i7_i5

    lima \\
        --neighbors \\
        -j 128 \\
        --peek-guess \\
        --ccs \\
        --min-score 26 \\
        --store-unbarcoded \\
        --split-named \\
        --log-level INFO \\
        --log-file demux_i7_i5/${meta.sample_ID}.lima.log \\
        ${bam} \\
        barcode_neighbor.fa \\
        demux_i7_i5/${meta.sample_ID}.bam

    mv demux_i7_i5/${meta.sample_ID}.lima.counts demux_i7_i5/i7_i5_${meta.sample_ID}.lima.counts
    mv demux_i7_i5/${meta.sample_ID}.lima.summary demux_i7_i5/i7_i5_${meta.sample_ID}.lima.summary
    """
}
