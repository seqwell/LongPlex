process DEMUX_STATS {
    tag "${meta.pool_ID}"

    input:
    tuple val(meta), path(stat)

    output:
    tuple val(meta), path('*.csv'), emit: metrics

    script:
    """
    create_demux_summary.R ${meta.pool_ID}
    """
}
