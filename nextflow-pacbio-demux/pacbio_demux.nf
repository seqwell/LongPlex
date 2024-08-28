#!/usr/local/bin/nextflow


include { lima_both_end } from './modules/lima_i7_i5_both_end.nf'
include { lima_either_end } from './modules/lima_i7_i5_either_end.nf'
include { LIST_HYBRIDS }  from './modules/listHybrids.nf'
include { REMOVE_HYBRIDS }  from './modules/removeHybrids.nf'
include { merge_reads } from './modules/merge_reads.nf'
include { demux_stats } from './modules/demux_stats.nf'
include { fastqc }  from './modules/fastqc.nf'
include { multiqc }  from './modules/multiqc.nf'


workflow {

params.samplesheet = "samplesheet.csv"
params.outdir      = "LongPlex_demux_out"


samples =Channel
    .fromPath(params.samplesheet)
    .splitCsv(header: true)
    .map { row -> tuple(row.sample_ID, file(row.sample_path), file(row.i7_barcode), file(row.i5_barcode)) }
    

bams = samples
       .map{ it -> tuple( it[0], it[1])}

count = reads_count(bams)

barcode = samples
           .map{ it -> tuple( it[0], it[2], it[3])}
           


lima_both_end_process = lima_both_end( samples)

lima_report = lima_both_end_process.i7_i5_lima_report
lima_unbarcoded_both_end = lima_both_end_process.unbarcoded

hybrid_list = LIST_HYBRIDS(lima_report)

unbarcoded_clean = REMOVE_HYBRIDS(lima_unbarcoded_both_end, hybrid_list)

unbarcoded_clean = unbarcoded_clean
                   .map { it -> tuple( it.baseName.tokenize(".")[0], it)}

unbarcoded_clean_barcode = unbarcoded_clean
                            .join( barcode, by:0)
                       

lima_either_end_process = lima_either_end( unbarcoded_clean_barcode)


both_end_bam =  lima_both_end_process.i7_i5_bam
either_end_bam = lima_either_end_process.either_i7_i5_bam

both_end_lima_count =  lima_both_end_process.i7_i5_lima_count
either_end_lima_count = lima_either_end_process.either_i7_i5_lima_count
both_end_lima_summary = lima_both_end_process.i7_i5_lima_summary
either_end_lima_summary = lima_either_end_process.either_i7_i5_lima_summary



i7_i5_bam_modified = both_end_bam
                      .map{it -> it[1]}
                      .flatten()
                      .map{ it -> tuple(it.baseName.tokenize('--')[0].tokenize('.')[0],
                                        it.baseName.tokenize('--')[0].tokenize('_')[2],
                                        it
                                    )}
                                    


i7_5_bam_modified = either_end_bam
                   .map{it -> it[1]}
                   .flatten()
                   .map{ it -> tuple(it.baseName.tokenize('--')[0].tokenize('.')[0],
                                    it.baseName.tokenize('--')[0].tokenize('_')[2],
                                    it
                                    )}
                                    

                                    
i7_i5_bam = i7_i5_bam_modified
            .mix(i7_5_bam_modified)
            .groupTuple(by: [0,1])
            


merged = merge_reads(i7_i5_bam)
merged_fastq = merged.fq
merged_bam = merged.bam

stat_ch = both_end_lima_count
         .mix(either_end_lima_count)
         .mix(both_end_lima_summary)
         .mix(either_end_lima_summary)
         .groupTuple(by: 0) 
         .map {it -> tuple (it[0], it[1].flatten())}
         
demux_stats(stat_ch)

fastqc_res = fastqc(merged_fastq)
fastqc_files = fastqc_res.metrics.collect().ifEmpty([])

multiqc(fastqc_files)


}



workflow.onComplete {
    println "Project output directory: ${workflow.projectDir}/${params.outdir}"
    println "Pipeline completed at: $workflow.complete"
    println "Pipeline completed time duration: $workflow.duration"
    println "Command line: $workflow.commandLine"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
 }

 workflow.onError {
    println "Error: Pipeline execution stopped with the following message: ${workflow.errorMessage}"
}


          
