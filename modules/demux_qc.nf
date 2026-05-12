process DEMUX_QC {
    tag "${meta.pool_ID}"
    label 'process_low'
   // publishDir "${params.output}/demux_stats", mode: 'copy'
    
    //container   'quay.io/biocontainers/pandas:1.5.2' 
    input:
    tuple val(meta),
          path(report_both),
          path(report_either),
          path(counts_both),
          path(counts_either),
          path(summary_both),
          path(nanostat_files),
          path(unbarcoded_nanostat),
          path(sample_map)

    output:
    tuple val(meta), path("${meta.pool_ID}_*.csv")

    script:
    def sample_map_arg = sample_map ? "--sample-map ${sample_map}" : ""
    """
    merge_demux_stats.py \\
        --report-both         ${report_both}         \\
        --report-either       ${report_either}        \\
        --counts-both         ${counts_both}          \\
        --counts-either       ${counts_either}        \\
        --summary-both        ${summary_both}         \\
        --nanostat            ${nanostat_files}       \\
        --unbarcoded-nanostat ${unbarcoded_nanostat}  \\
        ${sample_map_arg}                             \\
        --output              ${meta.pool_ID}_per_barcode_qc_report.csv \\
        --summary-output      ${meta.pool_ID}_per_pool_qc_report.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
        pandas: \$(python -c "import pandas; print(pandas.__version__)")
    END_VERSIONS
    """
}