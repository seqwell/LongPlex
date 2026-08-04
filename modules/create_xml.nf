process CREATE_XML {
    tag "${meta.pool_ID}"

    input:
    tuple val(meta), path(bams)

    output:
    tuple val(meta), path("*.combined.consensusreadset.xml"), emit: xml

    script:
    """
    dataset create \\
        --generateIndices --force --type ConsensusReadSet \\
        ${meta.pool_ID}.combined.consensusreadset.xml \\
        ${bams}
    
    sed -i -E 's#(ResourceId=")[^"]*/([^/"]+)"#\\1${params.output}/${meta.pool_ID}/\\2"#g' \
    ${meta.pool_ID}.combined.consensusreadset.xml

    """
}