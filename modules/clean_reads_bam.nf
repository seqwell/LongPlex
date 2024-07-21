
process clean_reads_bam {

tag "${sample_id}_${well_id}"

publishDir path: "${params.outdir}/${sample_id}/bbduk_out/bam/passFilterBam", pattern: 'passFilter*bam', mode: 'copy'
publishDir path: "${params.outdir}/${sample_id}/bbduk_out/bam/failFilterBam", pattern: '*failFilter*bam', mode: 'copy'
publishDir path: "${params.outdir}/${sample_id}/bbduk_out/bam/stats", pattern: '*stat*', mode: 'copy'


input:
tuple val(sample_id), val(well_id), path (bam) , path(barcode1), path(barcode2)



output:
tuple val(sample_id), val(well_id), path ("passFilter*.bam") ,      emit: passFilter_bam
tuple val(sample_id), val(well_id), path ("*failFilter*.bam"),      emit: failFilter_bam 
tuple val(sample_id),  path ("*stat*")                       ,      emit: bbduk_stat



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
