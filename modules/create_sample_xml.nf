process CREATE_SAMPLE_XML {
    tag "${meta.pool_ID}.${meta.sample_ID}"

    input:
    tuple val(meta), path(bams)
    val(output_dir)

    output:
    tuple val(meta), path("${meta.sample_ID}.consensusreadset.xml"), emit: xml

    script:
    """
    python ${projectDir}/bin/create_sample_xml.py \\
        --pool-id '${meta.pool_ID}' \\
        --sample-id '${meta.sample_ID}' \\
        --output-dir '${output_dir}' \\
        ${bams}
    """
}