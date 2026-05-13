process MULTIQC {
    
    tag "${meta.pool_ID}"
    input:
    tuple val(meta), path(nanostat_reports)
    output:
    path("${meta.pool_ID}_multiqc_report_*.html")
    script:
    """
    timestamp=\$(date +%Y%m%d_%H%M%S)
    for f in \$(ls ${nanostat_reports} | sort -V); do
        newname=\$(basename \$f | sed 's/_nanostat.txt//')
        cp \$f \${newname}.txt
    done
    multiqc *_nanostat.txt \\
        --fullnames \\
        --filename ${meta.pool_ID}_multiqc_report_\${timestamp}.html
    """
}
