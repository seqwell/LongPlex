
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