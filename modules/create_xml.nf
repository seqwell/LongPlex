process CREATE_XML {
    tag "${meta.pool_ID}"
    
    input:
    tuple val(meta), path(bams)
    output:
    tuple val(meta), path("*.combined.consensusreadset.xml"), emit: xml
    script:
    """
    create_combined_xml.py ${meta.pool_ID} ${bams}

    sed -i -E 's#(ResourceId=")[^"]*/([^/"]+)"#\\1${params.output}/merged_bam/${meta.pool_ID}/\\2"#g' \\
    ${meta.pool_ID}.combined.consensusreadset.xml
    """
}