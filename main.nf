#!/usr/bin/env nextflow

include { validateParameters; paramsSummaryLog; samplesheetToList } from 'plugin/nf-schema'

include { DEMUX_STATS } from './modules/demux_stats.nf'
include { LIMA_BOTH_END } from './modules/lima_i7_i5_both_end.nf'
include { LIMA_EITHER_END } from './modules/lima_i7_i5_either_end.nf'
include { LIST_HYBRIDS } from './modules/list_hybrids.nf'
include { MERGE_READS } from './modules/merge_reads.nf'
include { REMOVE_HYBRIDS } from './modules/remove_hybrids.nf'
include { RENAME_DEMUX_STATS }  from './modules/rename_demux_stats.nf'
include { NANOSTAT } from './modules/nanostat.nf'
include { MULTIQC } from './modules/multiqc.nf'

def infer_well(path) {
    def well_id = path.tokenize("_")[2]
    well_id
}

workflow {
    validateParameters()
    log.info paramsSummaryLog(workflow)
    def pools_ch = Channel.fromList(samplesheetToList(params.pool_sheet, "schemas/input_schema.json"))

    // Build rename map as a plain Groovy map, not a channel
    def rename_maps = [:]
    if (params.rename_map) {
        file(params.rename_map)
            .readLines()
            .drop(1)  // skip header
            .each { line ->
                def parts = line.trim().split(",")
                if (parts.size() == 2) {
                    rename_maps[parts[0].trim()] = parts[1].trim()
                }
            }
    }
    log.info "Rename maps: ${rename_maps}"

    LIMA_BOTH_END(pools_ch)
    LIST_HYBRIDS(LIMA_BOTH_END.out.report)
    REMOVE_HYBRIDS(LIMA_BOTH_END.out.bam_unbarcoded_and_barcodes, LIST_HYBRIDS.out.hybrids)
    LIMA_EITHER_END(REMOVE_HYBRIDS.out.bam_filtered_and_barcodes)

    def bams_by_well_ch = LIMA_BOTH_END.out.bam
        .join(LIMA_EITHER_END.out.bam)
        .map { meta, both_bams, either_bams ->
            def both_list = both_bams instanceof List ? both_bams : [both_bams]
            def either_list = either_bams instanceof List ? either_bams : [either_bams]
            tuple(meta, both_list + either_list)
        }
        .flatMap { meta, bams ->
            bams.collect { bam ->
                tuple(meta + [well_ID: infer_well(bam.getBaseName())], bam)
            }
        }
        .groupTuple(by: 0)

    def bams_by_well_named_ch = bams_by_well_ch
        .map { meta, bams ->
            def key = "${meta.pool_ID}.${meta.well_ID}"
            def sample = rename_maps[key]
           // log.info "KEY: '${key}' | MATCH: ${sample}"
            def new_meta = meta + [
                sample_ID: sample ?: key
            ]
            tuple(new_meta, bams)
        }

    MERGE_READS(bams_by_well_named_ch)

    def stat_ch = LIMA_BOTH_END.out.counts
        .mix(LIMA_EITHER_END.out.counts, LIMA_BOTH_END.out.summary, LIMA_EITHER_END.out.summary)
        .groupTuple(by: 0)
        .map { meta, stats -> tuple(meta, stats.flatten()) }

    DEMUX_STATS(stat_ch)
    
    def final_stats_ch

    if (params.rename_map) {
        // Use the Python process we created
        def rename_map_file = file(params.rename_map)
        
        RENAME_DEMUX_STATS(DEMUX_STATS.out, rename_map_file)
        final_stats_ch = RENAME_DEMUX_STATS.out.csv
    } else {
        final_stats_ch = DEMUX_STATS.out
    }
    
    
     NANOSTAT(MERGE_READS.out.fastq)
    
    
    ch_multiqc_input = NANOSTAT.out.report
        .map { meta, report -> tuple( meta.pool_ID, report) }  // drop per-sample meta, key by pool
        .groupTuple()  
        .map { pool_id, reports -> tuple(pool_id, reports.flatten()) }
        //.view { pool_id, reports -> "Pool: ${pool_id} | Reports: ${reports}" }

    MULTIQC(ch_multiqc_input)
    
    

    workflow.onComplete = {
        println "Project output directory: ${workflow.projectDir}/${params.output}"
        println "Pipeline completed at: $workflow.complete"
        println "Pipeline completed time duration: $workflow.duration"
        println "Command line: $workflow.commandLine"
        println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    }

    workflow.onError = {
        println "Error: Pipeline execution stopped with the following message: ${workflow.errorMessage}"
    }
}