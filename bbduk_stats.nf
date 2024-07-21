
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