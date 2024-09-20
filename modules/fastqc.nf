process FASTQC {
    tag "${meta.sample_ID}"

    input:
    tuple val(meta), val(well_id), path(reads)

    output:
    path("*.html"), emit: report
    path("*.zip"), emit: archive

    script:
    """
    fastqc -q $reads
    """
}
