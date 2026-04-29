process MULTIQC {
    
    tag "${pool_id}"

    input:
    tuple val(pool_id), path(nanostat_reports)

    output:
    path("${pool_id}_ONT_multiqc_report.html")

    script:
    """
    # Create sample rename file: old_name -> new_name
    for f in \$(ls ${nanostat_reports} | sort -V); do
        newname=\$(basename \$f | sed 's/_nanostat.txt//')
        cp \$f \${newname}.txt
    done

     multiqc *_nanostat.txt \\
        --fullnames \\
        --filename ${pool_id}_ONT_multiqc_report.html
    """
}