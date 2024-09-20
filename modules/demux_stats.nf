process DEMUX_STATS {
    tag "${meta.sample_ID}"
    publishDir path: "${params.output}/${meta.sample_ID}/demux_summary", pattern: '*.csv', mode: 'copy'

    input:
    tuple val(meta), path(stat)

    output:
    path('*.csv'), emit: metrics

    script:
    """
    create_demux_summary.R ${meta.sample_ID}
    """
}
