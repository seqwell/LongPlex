
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
