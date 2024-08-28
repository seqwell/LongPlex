
process fastqc {
   
    

    input:
    tuple val(sample_id), val(well_id), path (reads)
 
    output:
    path("*.html"), emit: reports
    path("*.zip"), emit: metrics

 
    script:
    """
    fastqc -q $reads
    """


}



