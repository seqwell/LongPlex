#!/usr/local/bin/nextflow



params.samples = "*.bam"
params.barcodes_i7 = "full_set3_i7_shorter_barcodes.fa"
params.barcodes_i5 = "full_set3_i5_shorter_barcodes.fa"


(bam_ch_1, bam_ch_2, bam_ch_3 ) = Channel
           .fromPath(params.samples ) 
           .map { it -> tuple( it.baseName.tokenize('.')[2], it)}
           .into(3)
           

(barcode_fa_i7_1,barcode_fa_i7_2) = Channel
                .fromPath(  params.barcodes_i7 )
                .into(2)
                
(barcode_fa_i5_1,barcode_fa_i5_2)  = Channel
               .fromPath(  params.barcodes_i5 )
               .into(2)
               
bam_ch_3.view()               
process reads_count {

publishDir path: 'hifibam_count',  mode: 'copy'

container 'quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1'

input:
tuple val(pair_id), path(bam) from bam_ch_1

output:
tuple val(pair_id), path("*.hifi.reads.count") into bam_count_ch

"""
echo  ${pair_id} > id
samtools view -c $bam > count
paste id count > ${pair_id}.hifi.reads.count 


"""

}


process lima {

container 'quay.io/biocontainers/lima:2.7.1--h9ee0642_0'

publishDir path: 'lima_out', pattern: 'demux_*/*', mode: 'copy'


input:
tuple val(pair_id), path(bam) from bam_ch_2
each path(barcode1) from barcode_fa_i7_1
each path(barcode2) from barcode_fa_i5_1

output:
path ('demux_i7/*')
path ('demux_i5/*')
tuple val(pair_id), path ('demux_i7/*--*.bam') into i7_bam
tuple val(pair_id), path ('demux_i5/*--*.bam') into i5_bam
tuple val(pair_id), path ("demux_i7/*lima.counts") into i7_lima_count
tuple val(pair_id), path ("demux_i5/*lima.counts") into i5_lima_count



"""
mkdir -p demux_i7
lima --single-side  -j 128 --peek-guess  --ccs --min-score 26 \
--store-unbarcoded \
--split-named --log-level INFO \
--log-file demux_i7/${pair_id}.lima.log \
${bam} \
${barcode1} \
demux_i7/${pair_id}.bam


mkdir -p demux_i5
lima --single-side  -j 128 --peek-guess  --ccs --min-score 26 \
--split-named --log-level INFO \
--log-file demux_i5/${pair_id}.lima.log \
demux_i7/${pair_id}.unbarcoded.bam \
${barcode2} \
demux_i5/${pair_id}.bam

"""
}

//bc1003.seqwell_UDI3_H12_P7--seqwell_UDI3_H12_P7.bam
//bc1003.seqwell_UDI3_H11_P5--seqwell_UDI3_H11_P5.bam

//i7_bam.view()
//i5_bam.view()


i7_bam_modified = i7_bam
                  .map{it -> it[1]}
                  .flatten()
                  .map{ it -> tuple(it.baseName.tokenize('--')[0].tokenize('.')[0],
                                    it.baseName.tokenize('--')[0].tokenize('_')[2],
                                    it
                                    )}
                                         
                                         
i5_bam_modified = i5_bam
                  .map{it -> it[1]}
                  .flatten()
                  .map{ it -> tuple(it.baseName.tokenize('--')[0].tokenize('.')[0],
                                    it.baseName.tokenize('--')[0].tokenize('_')[2],
                                    it
                                    )}
                                        
i7_i5_bam = i7_bam_modified
            .join(i5_bam_modified, by: [0,1])

process merge_bam_to_fq {

container 'quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1'
input:
  tuple val(pair_id), val(well_id), path (bam_i7), path(bam_i5) from i7_i5_bam
  

output:
  tuple val(pair_id), val(well_id), path ("*.fastq.gz") into merged_fq
  

"""
samtools  merge ${pair_id}.${well_id}.bam $bam_i7 $bam_i5
samtools fastq ${pair_id}.${well_id}.bam | bgzip -c > ${pair_id}.${well_id}.fastq.gz

"""

}  


process bbduk_filter {

container 'staphb/bbtools:39.01'
publishDir path: 'bbduk_out_passFilter', pattern: '*.passFilter.fastq.gz', mode: 'copy'
publishDir path: 'bbduk_out_failFilter', pattern: '*.failFilter.fastq.gz', mode: 'copy'
publishDir path: 'bbduk_stats', pattern: '*.stats.txt', mode: 'copy'

input:
  tuple val(pair_id), val(well_id), path (fq) from merged_fq
  each path(barcode1) from barcode_fa_i7_2
  each path(barcode2) from barcode_fa_i5_2

output:
  tuple val(pair_id), val(well_id), path ("*.passFilter.fastq.gz") 
  tuple val(pair_id), val(well_id), path ("*.failFilter.fastq.gz") 
  tuple val(pair_id),  path ("*.stats.txt") into stats
  path ("adapter_info") into adapter_info


"""

cat $barcode1 $barcode2 | paste - - | cut -f2 | tr '\n' ',' > barcode.txt
bbduk.sh -Xmx2g \
in=$fq \
literal=\$(cat barcode.txt)  \
out=${pair_id}.${well_id}.unmatched.fastq.gz \
outm=${pair_id}.${well_id}.matched.fastq.gz  \
k=44 \
hdist=1 \
stats=${pair_id}.${well_id}.stats.txt  \
2>>log

if [ -f ${pair_id}.${well_id}.unmatched.fastq.gz ]; then
mv ${pair_id}.${well_id}.unmatched.fastq.gz ${pair_id}.${well_id}.passFilter.fastq.gz
fi
if [ -f ${pair_id}.${well_id}.matched.fastq.gz ]; then
mv ${pair_id}.${well_id}.matched.fastq.gz ${pair_id}.${well_id}.failFilter.fastq.gz
fi


cat $barcode1 $barcode2 | paste - - > adapter_2_col.txt
cat -n adapter_2_col.txt | awk '{print \$1}' > a
cat -n adapter_2_col.txt | awk '{print \$2}' | cut -d_ -f3,4 | cut -d_ -f1 > b
cat -n adapter_2_col.txt | awk '{print \$2}' | cut -d_ -f3,4 | cut -d_ -f2 > c
paste a b c > adapter_info


"""


}



stat_ch = stats
          .groupTuple(by: 0)        

process bbduk_stats { 

container 'rocker/verse:4.3.1'

publishDir path: 'bbduk_summary', pattern: '*.csv', mode: 'copy'

input:
  tuple val(pair_id),  path (stat) from stat_ch
  path (adapter) from adapter_info


output:
  path("*.csv")

"""
create_bbduk_summary.R   $pair_id 
"""

}
