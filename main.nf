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

def infer_well(path) {
    def well_id = path.tokenize("_")[2]
    well_id
}

workflow {
    // Input Parsing
    validateParameters()
    log.info paramsSummaryLog(workflow)
    samples_ch = Channel.fromList(samplesheetToList(params.samplesheet, "schemas/input_schema.json"))

    // Pipeline
    LIMA_BOTH_END(samples_ch)

    LIST_HYBRIDS(LIMA_BOTH_END.out.report)

    REMOVE_HYBRIDS(LIMA_BOTH_END.out.bam_unbarcoded, LIST_HYBRIDS.out.hybrids)
    
    LIMA_EITHER_END(REMOVE_HYBRIDS.out.bam_filtered)

    bams_by_well_ch = LIMA_BOTH_END.out.bam
        .join(LIMA_EITHER_END.out.bam)
        .map { meta, both_bams, either_bams ->
            tuple(meta, both_bams + either_bams)
        }
        .flatMap { meta, bams ->
            bams.collect { bam -> 
                tuple(meta + [well_ID: infer_well(bam.getBaseName())], bam)
            }
        }.groupTuple(by: 0)

    MERGE_READS(bams_by_well_ch)

    stat_ch = LIMA_BOTH_END.out.counts
        .mix(LIMA_EITHER_END.out.counts, LIMA_BOTH_END.out.summary, LIMA_EITHER_END.out.summary)
        .groupTuple(by: 0) 
        .map {meta, stats -> tuple(meta, stats.flatten())}

    DEMUX_STATS(stat_ch)

    FASTQC(MERGE_READS.out.fastq)

    MULTIQC(FASTQC.out.archive.collect().ifEmpty([]))

    // Pipeline Cleanup
    workflow.onComplete  = {
        println "Project output directory: ${workflow.projectDir}/${params.output}"
        println "Pipeline completed at: $workflow.complete"
        println "Pipeline completed time duration: $workflow.duration"
        println "Command line: $workflow.commandLine"
        println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    }

    workflow.onError {
        println "Error: Pipeline execution stopped with the following message: ${workflow.errorMessage}"
    }
}
