
process demux_stats { 

tag "${sample_id}"


publishDir path: "${params.outdir}/${sample_id}/demux_summary", pattern: '*.csv', mode: 'copy'

input:
  tuple val(sample_id),  path (stat) 

  


output:
  tuple val(sample_id), path("*.csv")

"""
create_demux_summary.R   $sample_id 
"""

}