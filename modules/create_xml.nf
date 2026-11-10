process CREATE_XML {
    tag "${meta.sample_ID ?: meta.pool_ID}"
    
    input:
    tuple val(meta), path(bams)
    output:
    tuple val(meta), path("*.consensusreadset.xml"), emit: xml
    script:
    def prefix  = task.ext.prefix ?: "${meta.pool_ID}.combined"
    def out_dir = file(params.output).toUriString()   // absolute local path, or s3://... kept intact
    """
    create_xml.py --prefix ${prefix} ${meta.pool_ID} ${bams}

    sed -i -E 's#(ResourceId=")[^"]*/([^/"]+)"#\\1${out_dir}/${meta.pool_ID}/merged_bam/\\2"#g' \\
    ${prefix}.consensusreadset.xml
    """
}
