process MULTIQC {

    input:
    path('fastqc/*')

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
