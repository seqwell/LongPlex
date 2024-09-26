process DEMUX_STATS {
    tag "${meta.sample_ID}"
    publishDir path: "${output_path}/${meta.sample_ID}/demux_summary", pattern: '*.csv', mode: 'copy'

    input:
    tuple val(meta), path(stat)
    path(output_path)

    output:
    path('*.csv'), emit: metrics

    script:
    """
    create_demux_summary.R ${meta.sample_ID}
    """
}
