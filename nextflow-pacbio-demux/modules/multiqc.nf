
process multiqc {


    publishDir path: "${params.outdir}/fastqc", pattern: '*.html', mode: 'copy'

    input:
    file ('fastqc/*') 
 
    output:
    file "*fastqc_report.html" 
 
    script:
   
    def datetime = new Date().format("yyyy-MM-dd_HH-mm-ss", TimeZone.getTimeZone("UTC"))
    def filename = datetime + "_fastqc_report.html"
    
    """
    multiqc   . \\
        --filename ${filename} \\
        --force \\
        --interactive \\
        --no-data-dir \\
        --verbose 
    """
}

