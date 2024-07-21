#!/usr/local/bin/nextflow

include { validateParameters; paramsHelp; paramsSummaryLog; fromSamplesheet } from 'plugin/nf-validation'


include { reads_count } from './modules/reads_count.nf'
include { lima } from './modules/lima.nf'
include { merge_reads } from './modules/merge_reads.nf'
include { clean_reads_fq } from './modules/clean_reads_fq.nf'
include { clean_reads_bam } from './modules/clean_reads_bam.nf'
include { bbduk_stats } from './modules/bbduk_stats.nf'


include { fastqc as fastqc_pass  }  from './modules/fastqc.nf'
include { fastqc as fastqc_fail  }  from './modules/fastqc.nf'
include { fastqc as fastqc_unbarcoded  }  from './modules/fastqc_unbarcoded.nf'

include { multiqc as multiqc_pass }  from './modules/multiqc.nf'
include { multiqc as multiqc_fail }  from './modules/multiqc.nf'
include { multiqc as multiqc_unbarcoded }  from './modules/multiqc.nf'



if (params.help) {
   log.info paramsHelp("nextflow run \
-profile aws \
nextflow-pacbio-demux-bbduk-summary/pacbio_demux_bbduk.nf \
-c nextflow-pacbio-demux-bbduk-summary/nextflow.config \
--samplesheet ${PWD}/samplesheet/samplesheet.csv \
--outdir  ${PWD}/output/LongPlex_demux_out \
-with-report \
-with-trace  \
-bg -resume")
   exit 0
}


validateParameters()

log.info paramsSummaryLog(workflow)





workflow {


Channel.fromSamplesheet("samplesheet")
        .multiMap { meta, sample_path, i7_barcode, i5_barcode ->
            barcode: tuple(meta.sample_ID, i7_barcode, i5_barcode )
            bams: tuple( meta.sample_ID, sample_path )
            bam_barcode: tuple( meta.sample_ID, sample_path, i7_barcode, i5_barcode )
        }
        .set { samples }
    
    
    


count = reads_count(samples.bams)



           
lima_process = lima( samples.bam_barcode)

both_end_bam =  lima_process.i7_i5_bam
either_end_bam = lima_process.either_i7_i5_bam

both_end_lima_count =  lima_process.i7_i5_lima_count
either_end_lima_count = lima_process.either_i7_i5_lima_count




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


merged_fastq_barcode = samples.barcode
                       .cross(merged_fastq)
                       .map{ it -> tuple ( it[0][0], it[1][1], it[1][2], it[0][1], it[0][2])}
                       

                       
merged_bam_barcode = samples.barcode
                       .cross(merged_bam)
                       .map{ it -> tuple ( it[0][0], it[1][1], it[1][2], it[0][1], it[0][2])}                    

bbduk_clean = clean_reads_fq(merged_fastq_barcode)
bbduk_clean_bam = clean_reads_bam(merged_bam_barcode)


fass_filter_fastq = bbduk_clean.fassFilter_fastq

bbduk_stats = bbduk_clean.bbduk_stat

adapter = bbduk_clean.adapter_info


stat_ch = bbduk_stats.mix(count).mix(both_end_lima_count).mix(either_end_lima_count)
         .groupTuple(by: 0) 
         .map {it -> tuple (it[0], it[1].flatten())}



bbduk_stats( stat_ch, adapter)



fastqc_pass = fastqc_pass(bbduk_clean_bam.passFilter_bam)
fastqc_fail = fastqc_fail(bbduk_clean_bam.failFilter_bam)
fastqc_unbarcode = fastqc_unbarcoded(lima_process.unbarcoded)


pass_fastqc_files = fastqc_pass.metrics.collect().ifEmpty([])
fail_fastqc_files = fastqc_fail.metrics.collect().ifEmpty([])
unbarcoded_fastqc_files = fastqc_unbarcode.metrics.collect().ifEmpty([])

multiqc_pass(pass_fastqc_files)
multiqc_fail(fail_fastqc_files)
multiqc_unbarcoded(unbarcoded_fastqc_files)

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


          
