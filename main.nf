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
include { NANOSTAT_UNBARCODED } from './modules/nanostat_unbarcoded.nf'
include { MULTIQC } from './modules/multiqc.nf'
include { DEMUX_QC } from './modules/demux_qc.nf'

def infer_well(path) {
    def well_id = path.tokenize("_")[2]
    well_id
}

workflow {
    validateParameters()
    log.info paramsSummaryLog(workflow)
    def pools_ch = Channel.fromList(samplesheetToList(params.pool_sheet, "schemas/input_schema.json"))

    def rename_maps = [:]
   
     
     if (params.rename_map) {
    def rename_rows = samplesheetToList(params.rename_map, "schemas/rename_map_schema.json")
        rename_rows.each { row ->
        rename_maps[row[0]] = row[1]
    }
     }
    log.info "Rename maps: ${rename_maps}"

    LIMA_BOTH_END(pools_ch)
    LIST_HYBRIDS(LIMA_BOTH_END.out.report)
    REMOVE_HYBRIDS(LIMA_BOTH_END.out.bam_unbarcoded_and_barcodes, LIST_HYBRIDS.out.hybrids)
    LIMA_EITHER_END(REMOVE_HYBRIDS.out.bam_filtered_and_barcodes)

    // Run NanoStat on unbarcoded BAM from either-end step (one per pool)
    NANOSTAT_UNBARCODED(LIMA_EITHER_END.out.bam_unbarcoded)

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
            def new_meta = meta + [sample_ID: sample ?: key]
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
        def rename_map_file = file(params.rename_map)
        RENAME_DEMUX_STATS(DEMUX_STATS.out, rename_map_file)
        final_stats_ch = RENAME_DEMUX_STATS.out.csv
    } else {
        final_stats_ch = DEMUX_STATS.out
    }

    NANOSTAT(MERGE_READS.out.fastq)

        
    ch_multiqc_input = NANOSTAT.out.report
    .map { meta, report -> tuple(meta.pool_ID, meta, report) }
    .groupTuple(by: 0)
    .map { pool_id, metas, reports ->
        def pool_meta = [pool_ID: pool_id]
        tuple(pool_meta, reports.flatten())
    }

MULTIQC(ch_multiqc_input)

    // ── MERGE_DEMUX_STATS — one per pool, pools never mixed ─────────────────

    // Keep full meta (with pool_ID) throughout — add id field for joining
    def lima_reports_ch = LIMA_BOTH_END.out.report
        .join(LIMA_EITHER_END.out.report)
        // tuple(meta{pool_ID}, report_both, report_either)
        // Both channels share the same meta from pools_ch so join works directly

    def lima_counts_ch = LIMA_BOTH_END.out.counts
        .join(LIMA_EITHER_END.out.counts)
        // tuple(meta{pool_ID}, counts_both, counts_either)

    // Group per-sample nanostats by pool_ID — keyed by pool_ID string
    def nanostat_by_pool_ch = NANOSTAT.out.report
        .map { meta, report -> tuple(meta.pool_ID, report) }
        .groupTuple()
        // tuple("bc1015", [s1.txt, s2.txt, ...])
        // tuple("bc1016", [s1.txt, s2.txt, ...])

    // Unbarcoded nanostat — one per pool, keyed by pool_ID string
    def nanostat_unbarcoded_ch = NANOSTAT_UNBARCODED.out.report
        .map { meta, report -> tuple(meta.pool_ID, report) }
        // tuple("bc1015", bc1015_unbarcoded_nanostat.txt)
        // tuple("bc1016", bc1016_unbarcoded_nanostat.txt)
    def lima_summary_ch = LIMA_BOTH_END.out.summary

    // Join all channels on pool_ID — each pool stays separate
    def merge_demux_input_ch = lima_reports_ch
    .join(lima_counts_ch)
    .join(lima_summary_ch)   // ← join summary_both here
    .map { meta, report_both, report_either, counts_both, counts_either, summary_both ->
        tuple(meta.pool_ID, meta, report_both, report_either, counts_both, counts_either, summary_both)
    }
    .join(nanostat_by_pool_ch)
    .join(nanostat_unbarcoded_ch)
    .map { pool_id, meta, report_both, report_either, counts_both, counts_either,
           summary_both, nanostat_files, unbarcoded_report ->
        def sample_map = params.rename_map ? file(params.rename_map) : []
        tuple(meta, report_both, report_either, counts_both, counts_either,
              summary_both, nanostat_files, unbarcoded_report, sample_map)
    }

    DEMUX_QC(merge_demux_input_ch)

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