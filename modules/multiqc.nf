process MULTIQC {

    input:
    path('fastqc/*')
    path('demux_i7_i5/*')
    path('demux_either_i7_i5/*')

    output:
    path('*multiqc_report.html')

    script:
    def datetime = new Date().format("yyyy-MM-dd_HH-mm-ss", TimeZone.getTimeZone("UTC"))
    def filename = datetime + "_multiqc_report.html"
    """
    multiqc . \\
        --filename ${filename} \\
        --force \\
        --interactive \\
        --no-data-dir \\
        --verbose
    """
}
