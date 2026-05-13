process NANOSTAT_UNBARCODED {
    tag "${meta.pool_ID}"
    label 'process_low'
    container "quay.io/biocontainers/nanostat:1.6.0--pyhdfd78af_0"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.pool_ID}_unbarcoded_nanostat.txt"), emit: report
    path "versions.yml",                                               emit: versions

    script:
    """
    # Use pysam (already in container) to convert BAM -> FASTQ, bypassing header check
    python3 - <<'EOF'
import pysam

with pysam.AlignmentFile("${bam}", "rb", check_sq=False) as inbam, \\
     open("unbarcoded_reads.fastq", "w") as fq:
    for read in inbam:
        if read.query_sequence is None:
            continue
        qual = read.query_qualities
        qual_str = ''.join(chr(q + 33) for q in qual) if qual is not None else 'I' * len(read.query_sequence)
        fq.write(f"@{read.query_name}\\n{read.query_sequence}\\n+\\n{qual_str}\\n")
EOF

    NanoStat \\
        --fastq unbarcoded_reads.fastq \\
        --tsv \\
        --outdir . \\
        --name ${meta.pool_ID}_unbarcoded_nanostat.txt \\
        -t ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanostat: \$(NanoStat --version | sed 's/NanoStat //')
    END_VERSIONS
    """
}