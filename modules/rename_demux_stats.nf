process RENAME_DEMUX_STATS {
    tag "${meta.pool_ID}"
    label 'process_low'

    input:
    tuple val(meta), path(csv_report)
    path rename_map

    output:
    path("*_renamed.csv"), emit: csv

    script:
    """
    rename_demux_stats.py ${csv_report} ${rename_map} "${meta.pool_ID}_demux_report_renamed.csv"
    """
}
