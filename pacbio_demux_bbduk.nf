#!/usr/local/bin/nextflow



params.samplesheet = "sample_sheet.csv"


samples =Channel
    .fromPath(params.samplesheet)
    .splitCsv(header: true)
    .map { row -> tuple(row.sample_ID, file(row.sample_path), file(row.i7_barcode), file(row.i5_barcode)) }
    



            
process reads_count {

publishDir path: 'hifibam_count',  mode: 'copy'

container 'quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1'

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

container 'quay.io/biocontainers/lima:2.7.1--h9ee0642_0'

publishDir path: 'lima_out', pattern: 'demux_*/*', mode: 'copy'


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




            
            
            
process merge_fq {

//publishDir path: 'fastq_merged_i5_i7', pattern: '*', mode: 'copy'

container 'quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1'
input:
  tuple val(sample_id), val(well_id), path(bam) 
  

output:
  tuple val(sample_id), val(well_id), path ("*.fastq.gz") 
  

"""
samtools  merge ${sample_id}.${well_id}.bam $bam
samtools fastq ${sample_id}.${well_id}.bam | bgzip -c > ${sample_id}.${well_id}.fastq.gz

"""

}                          



process clean_reads {


publishDir path: 'bbduk_out_i7_i5', pattern: '*', mode: 'copy'

container 'staphb/bbtools:39.01'


input:
tuple val(sample_id), val(well_id), path (bam) , path(barcode1), path(barcode2)



output:
tuple val(sample_id), val(well_id), path ("passFilter*.fastq.gz") , emit: fassFilter_fastq
tuple val(sample_id),  path ("*stat*")                            , emit: bbduk_stat
path ("adapter_info")                                             , emit: adapter_info

"""


#filter for i5
cat $barcode2 | sed 's/^T//g' > barcode2.fa
bbduk.sh -Xmx2g \
in=$bam \
ref=barcode2.fa  \
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
cat $barcode1 |   sed 's/^T//g' > barcode1.fa
bbduk.sh -Xmx2g \
in=clean.${sample_id}.${well_id}.fastq.gz \
ref=barcode1.fa  \
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
mv ${sample_id}.${well_id}.matched.fastq.gz i7.i5.${sample_id}.${well_id}.failFilter.fastq.gz
fi





cat $barcode1 $barcode2 | grep '>' | sed 's/>//g'  > a
cat  a | cut -d_ -f3,4 | cut -d_ -f1 > b
cat  a | cut -d_ -f3,4 | cut -d_ -f2 > c
paste a b c > adapter_info

"""



}   




          
          
process bbduk_stats { 

container 'rocker/verse:4.3.1'

publishDir path: 'bbduk_summary', pattern: '*.csv', mode: 'copy'

input:
  tuple val(sample_id),  path (stat) 
  path (adapter) 
  


output:
  path("*.csv")

"""
create_bbduk_summary.R   $sample_id 
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


both_end_bam.view()

i7_i5_bam_modified = both_end_bam
                      .map{it -> it[1]}
                      .flatten()
                      .map{ it -> tuple(it.baseName.tokenize('--')[0].tokenize('.')[0],
                                        it.baseName.tokenize('--')[0].tokenize('_')[2],
                                        it
                                    )}
                                    
i7_i5_bam_modified.view()
 either_end_bam.view()

i7_5_bam_modified = either_end_bam
                   .map{it -> it[1]}
                   .flatten()
                   .map{ it -> tuple(it.baseName.tokenize('--')[0].tokenize('.')[0],
                                    it.baseName.tokenize('--')[0].tokenize('_')[2],
                                    it
                                    )}
                                    
i7_5_bam_modified.view()
                                    
i7_i5_bam = i7_i5_bam_modified
            .mix(i7_5_bam_modified)
            .groupTuple(by: [0,1])
            
//i7_i5_bam.view()


merged_fastq = merge_fq(i7_i5_bam)
//merged_fastq.view()

//barcode.view()
merged_fastq_barcode = barcode
                       .cross(merged_fastq)
                       .map{ it -> tuple ( it[0][0], it[1][1], it[1][2], it[0][1], it[0][2])}
                       
                       
merged_fastq_barcode.view()

bbduk_clean = clean_reads(merged_fastq_barcode)

//bbduk_clean.view()

fass_filter_fastq = bbduk_clean.fassFilter_fastq

bbduk_stats = bbduk_clean.bbduk_stat

adapter = bbduk_clean.adapter_info

//bbduk_stats.view()
//count.view()
//both_end_lima_count.view()
//either_end_lima_count.view()
stat_ch = bbduk_stats.mix(count).mix(both_end_lima_count).mix(either_end_lima_count)
       .groupTuple(by: 0) 
        .map {it -> tuple (it[0], it[1].flatten())}

//stat_ch.view()

bbduk_stats( stat_ch, adapter)

}



          