process FASTQC {
    tag "${meta.pool_ID}"

    input:
    tuple val(meta), path(reads)

    output:
    path("*.html"), emit: report
    path("*.zip"), emit: archive

    script:
    """
    fastqc -q $reads
    """
}
