#!/usr/bin/env nextflow

include { validateParameters; paramsSummaryLog; samplesheetToList } from 'plugin/nf-schema'

include { DEMUX_STATS } from './modules/demux_stats.nf'
include { FASTQC } from './modules/fastqc.nf'
include { LIMA_BOTH_END } from './modules/lima_i7_i5_both_end.nf'
include { LIMA_EITHER_END } from './modules/lima_i7_i5_either_end.nf'
include { LIST_HYBRIDS } from './modules/list_hybrids.nf'
include { MERGE_READS } from './modules/merge_reads.nf'
include { MULTIQC } from './modules/multiqc.nf'
include { REMOVE_HYBRIDS } from './modules/remove_hybrids.nf'

validateParameters()

log.info paramsSummaryLog(workflow)

def infer_well(path) { path.tokenize("_")[2] }

workflow {
    samples_ch = Channel.fromList(samplesheetToList(params.samplesheet, "schemas/input_schema.json"))

    LIMA_BOTH_END(samples_ch)

    LIST_HYBRIDS(LIMA_BOTH_END.out.report)

    REMOVE_HYBRIDS(LIMA_BOTH_END.out.bam_unbarcoded, LIST_HYBRIDS.out.hybrids)

    LIMA_EITHER_END(REMOVE_HYBRIDS.out.bam_filtered)

    bams_demux_ch = LIMA_BOTH_END.out.bam.collect().join(LIMA_EITHER_END.out.bam.collect())
    // Should be: [[meta, [bams]], ...]
    // But is currently [[meta, [both bams], [either bams]]]

    bams_by_well_ch = bams_demux_ch
        .flatMap { meta, bams ->
            bams.map { bam -> tuple(meta, infer_well(bam), bam) }
        }
        .groupTuple(by: 1)

    MERGE_READS(bams_by_well_ch)

    // stat_ch = lima_both_end_process.i7_i5_lima_count
    //     .mix(lima_either_end_process.either_i7_i5_lima_count)
    //     .mix(lima_both_end_process.i7_i5_lima_summary)
    //     .mix(lima_either_end_process.either_i7_i5_lima_summary)
    //     .groupTuple(by: 0) 
    //     .map {it -> tuple (it[0], it[1].flatten())}

    // DEMUX_STATS(stat_ch)

    // FASTQC(MERGE_READS.out.reads)

    // MULTIQC(FASTQC.out.report.collect())
}

workflow.onComplete {
    println "Project output directory: ${workflow.projectDir}/${params.output}"
    println "Pipeline completed at: $workflow.complete"
    println "Pipeline completed time duration: $workflow.duration"
    println "Command line: $workflow.commandLine"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

workflow.onError {
    println "Error: Pipeline execution stopped with the following message: ${workflow.errorMessage}"
}
