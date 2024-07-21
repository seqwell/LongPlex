
process fastqc {
   
    tag "${sample_id}"

    input:
    tuple val(sample_id), path (reads)
 
    output:
    path("*.html"), emit: reports
    path("*.zip"), emit: metrics
 
    script:
    """
    fastqc -q $reads
    """


}


