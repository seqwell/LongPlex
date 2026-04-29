process NANOSTAT {
    tag "${meta.sample_ID}"
    errorStrategy 'ignore'

    input:
    tuple val(meta), path(fastq)

    output:
    tuple val(meta), path("${meta.sample_ID}_nanostat.txt"), emit: report

    script:
    """
    NanoStat --fastq $fastq --tsv --threads ${task.cpus} > ${meta.sample_ID}_nanostat.txt
    """
}
