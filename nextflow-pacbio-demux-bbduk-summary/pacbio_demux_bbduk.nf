#!/usr/local/bin/nextflow



params.samplesheet = "samplesheet.csv"
params.outdir      = "LongPlex_demux_out"


samples =Channel
    .fromPath(params.samplesheet)
    .splitCsv(header: true)
    .map { row -> tuple(row.sample_ID, file(row.sample_path), file(row.i7_barcode), file(row.i5_barcode)) }
    

include { validateParameters; paramsHelp; paramsSummaryLog; samplesheetToList } from 'plugin/nf-schema'


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


ch_input = Channel.fromList(samplesheetToList(params.samplesheet, "assets/schema_input.json"))

            
process reads_count {

tag "${sample_id}"

publishDir path: "${params.outdir}/${sample_id}/hifibam_count",  mode: 'copy'


input:
tuple val(sample_id), path(bam)

output:
tuple val(sample_id), path("*.hifi.reads.count") 

"""
echo  ${sample_id} > id
samtools view -c $bam > count
paste id count > ${sample_id}.hifi.reads.count 


"""

}


process lima {

tag "${sample_id}"

publishDir path: "${params.outdir}/${sample_id}/lima_out", pattern: 'demux_*/*', mode: 'copy'


input:
tuple val(sample_id), path(bam), path(barcode1), path(barcode2)


output:
path ('demux_either_i7_i5/*')
path ('demux_i7_i5/*')
tuple val(sample_id), path ('demux_either_i7_i5/*--*.bam')         , emit: either_i7_i5_bam
tuple val(sample_id), path ('demux_i7_i5/*--*.bam')                , emit: i7_i5_bam
tuple val(sample_id), path ("demux_either_i7_i5/*lima.counts")     , emit: either_i7_i5_lima_count
tuple val(sample_id), path ("demux_i7_i5/*lima.counts")            , emit: i7_i5_lima_count


"""

cat $barcode1 $barcode2 | paste - -  | sort |  tr '\t' '\n' > barcode_neighbor.fa

mkdir -p demux_i7_i5
lima --neighbors  -j 128 --peek-guess  --ccs --min-score 26 \
--store-unbarcoded \
--split-named --log-level INFO \
--log-file demux_i7_i5/${sample_id}.lima.log \
${bam} \
barcode_neighbor.fa \
demux_i7_i5/${sample_id}.bam
mv demux_i7_i5/${sample_id}.lima.counts demux_i7_i5/i7_i5_${sample_id}.lima.counts 


cat $barcode1 $barcode2 > barcode.fa
mkdir -p demux_either_i7_i5
lima --single-side  -j 128 --peek-guess  --ccs --min-score 26 \
--store-unbarcoded \
--split-named --log-level INFO \
--log-file demux_i7/${sample_id}.lima.log \
demux_i7_i5/${sample_id}.unbarcoded.bam \
barcode.fa \
demux_either_i7_i5/${sample_id}.bam
mv demux_either_i7_i5/${sample_id}.lima.counts demux_either_i7_i5/i7_5_${sample_id}.lima.counts 


"""
}




            
            
            
process merge_reads {

tag "${sample_id}_${well_id}"

input:
  tuple val(sample_id), val(well_id), path(bam) 
  

output:
  tuple val(sample_id), val(well_id), path ("*.fastq.gz") , emit: fq
  tuple val(sample_id), val(well_id), path ("*.bam") ,      emit: bam
  

"""
samtools  merge ${sample_id}.${well_id}.bam $bam
samtools fastq ${sample_id}.${well_id}.bam | bgzip -c > ${sample_id}.${well_id}.fastq.gz

"""

}                          



process clean_reads_fq {

tag "${sample_id}_${well_id}"

publishDir path: "${params.outdir}/${sample_id}/bbduk_out/fastq/passFilterFastq", pattern: 'passFilter*fastq.gz', mode: 'copy'
publishDir path: "${params.outdir}/${sample_id}/bbduk_out/fastq/failFilterFastq", pattern: '*failFilter*fastq.gz', mode: 'copy'
publishDir path: "${params.outdir}/${sample_id}/bbduk_out/fastq/stats", pattern: '*stat*', mode: 'copy'



input:
tuple val(sample_id), val(well_id), path (bam) , path(barcode1), path(barcode2)



output:
tuple val(sample_id), val(well_id), path ("passFilter*.fastq.gz") , emit: fassFilter_fastq
tuple val(sample_id), val(well_id), path ("*failFilter*.fastq.gz") 
tuple val(sample_id),  path ("*stat*")                            , emit: bbduk_stat
path ("adapter_info")                                             , emit: adapter_info

"""


#filter for i5
bbduk.sh -Xmx2g \
in=$bam \
ref=$barcode2  \
out=${sample_id}.${well_id}.unmatched.fastq.gz \
outm=${sample_id}.${well_id}.matched.fastq.gz  \
k=43 \
hdist=1 \
stats=i5.${sample_id}.${well_id}.stats.txt  \
2>>log

if [ -f ${sample_id}.${well_id}.unmatched.fastq.gz ]; then
mv ${sample_id}.${well_id}.unmatched.fastq.gz clean.${sample_id}.${well_id}.fastq.gz
fi
if [ -f ${sample_id}.${well_id}.matched.fastq.gz ]; then
mv ${sample_id}.${well_id}.matched.fastq.gz i5.${sample_id}.${well_id}.failFilter.fastq.gz
fi




#filter for i7
bbduk.sh -Xmx2g \
in=clean.${sample_id}.${well_id}.fastq.gz \
ref=$barcode1  \
out=${sample_id}.${well_id}.unmatched.fastq.gz \
outm=${sample_id}.${well_id}.matched.fastq.gz  \
k=44 \
hdist=1 \
stats=i7.${sample_id}.${well_id}.stats.txt  \
2>>log

if [ -f ${sample_id}.${well_id}.unmatched.fastq.gz ]; then
mv ${sample_id}.${well_id}.unmatched.fastq.gz passFilter.${sample_id}.${well_id}.fastq.gz
fi
if [ -f ${sample_id}.${well_id}.matched.fastq.gz ]; then
mv ${sample_id}.${well_id}.matched.fastq.gz i7.${sample_id}.${well_id}.failFilter.fastq.gz
fi





cat $barcode1 $barcode2 | grep '>' | sed 's/>//g'  > a
cat  a | cut -d_ -f3,4 | cut -d_ -f1 > b
cat  a | cut -d_ -f3,4 | cut -d_ -f2 > c
paste a b c > adapter_info

"""



}   



process clean_reads_bam {

tag "${sample_id}_${well_id}"

publishDir path: "${params.outdir}/${sample_id}/bbduk_out/bam/passFilterBam", pattern: 'passFilter*bam', mode: 'copy'
publishDir path: "${params.outdir}/${sample_id}/bbduk_out/bam/failFilterBam", pattern: '*failFilter*bam', mode: 'copy'
publishDir path: "${params.outdir}/${sample_id}/bbduk_out/bam/stats", pattern: '*stat*', mode: 'copy'


input:
tuple val(sample_id), val(well_id), path (bam) , path(barcode1), path(barcode2)



output:
tuple val(sample_id), val(well_id), path ("passFilter*.bam") ,      emit: fassFilter_bam
tuple val(sample_id), val(well_id), path ("*failFilter*.bam"),      emit: failFilter_bam 
tuple val(sample_id),  path ("*stat*"),                             emit: bbduk_stat



"""


#filter for i5
bbduk.sh -Xmx2g \
in=$bam \
ref=$barcode2  \
out=${sample_id}.${well_id}.unmatched.bam \
outm=${sample_id}.${well_id}.matched.bam  \
k=43 \
hdist=1 \
stats=i5.${sample_id}.${well_id}.stats.txt  \
2>>log

if [ -f ${sample_id}.${well_id}.unmatched.bam ]; then
mv ${sample_id}.${well_id}.unmatched.bam clean.${sample_id}.${well_id}.bam
fi
if [ -f ${sample_id}.${well_id}.matched.bam ]; then
mv ${sample_id}.${well_id}.matched.bam i5.${sample_id}.${well_id}.failFilter.bam
fi




#filter for i7
bbduk.sh -Xmx2g \
in=clean.${sample_id}.${well_id}.bam \
ref=$barcode1  \
out=${sample_id}.${well_id}.unmatched.bam \
outm=${sample_id}.${well_id}.matched.bam  \
k=44 \
hdist=1 \
stats=i7.${sample_id}.${well_id}.stats.txt  \
2>>log

if [ -f ${sample_id}.${well_id}.unmatched.bam ]; then
mv ${sample_id}.${well_id}.unmatched.bam passFilter.${sample_id}.${well_id}.bam
fi
if [ -f ${sample_id}.${well_id}.matched.bam ]; then
mv ${sample_id}.${well_id}.matched.bam i7.${sample_id}.${well_id}.failFilter.bam
fi




"""



}   

          
          
process bbduk_stats { 

tag "${sample_id}"


publishDir path: "${params.outdir}/${sample_id}/demux_summary", pattern: '*.csv', mode: 'copy'

input:
  tuple val(sample_id),  path (stat) 
  path (adapter) 
  


output:
  path("*.csv")

"""
create_bbduk_summary.R   $sample_id 
"""

}

process fastqc {
   
    

    input:
    tuple val(sample_id), val(well_id), path (reads)
 
    output:
    file "*_fastqc.{zip,html}" 
 
    script:
    """
    fastqc -q $reads
    """


}



process multiqc {


    publishDir path: "${params.outdir}/fastqc", pattern: '*.html', mode: 'copy'

    input:
    file ('fastqc/*') 
 
    output:
    file "*fastqc_report.html" 
 
    script:
   
    def datetime = new Date().format("yyyy-MM-dd_HH-mm-ss", TimeZone.getTimeZone("UTC"))
    def filename = datetime + "_fastqc_report.html"
    
    """
    multiqc   . \\
        --filename ${filename} \\
        --force \\
        --interactive \\
        --no-data-dir \\
        --verbose 
    """
}


workflow {

bams = samples
       .map{ it -> tuple( it[0], it[1])}

count = reads_count(bams)

barcode = samples
           .map{ it -> tuple( it[0], it[2], it[3])}
           


lima_process = lima( samples)

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


merged_fastq_barcode = barcode
                       .cross(merged_fastq)
                       .map{ it -> tuple ( it[0][0], it[1][1], it[1][2], it[0][1], it[0][2])}
                       
merged_bam_barcode = barcode
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

fastqc = fastqc(bbduk_clean_bam.fassFilter_bam)

fastqc_files = fastqc.collect().ifEmpty([])

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


          
