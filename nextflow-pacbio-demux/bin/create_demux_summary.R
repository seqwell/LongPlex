#!/usr/bin/env Rscript
library(dplyr)
library(purrr)



args = commandArgs(trailingOnly=TRUE)

pair_id = args[[1]]

i7_i5_sum = list.files(pattern = "lima.summary")[[2]]
i7_5_sum = list.files(pattern = "lima.summary")[[1]]
i7_i5_counts= list.files(pattern = "lima.counts")[[2]]
i7_5_counts= list.files(pattern = "lima.counts")[[1]]
df1 = readr::read_table(i7_i5_sum, col_names = F)

col_names_ <- names(readr::read_table(i7_i5_counts, n_max = 0))
df2 = readr::read_table(i7_i5_counts, col_names = col_names_ , skip=2) 

df3 = readr::read_table(i7_5_sum, col_names = F)

col_names_ <- names(readr::read_table(i7_5_counts, n_max = 0))
df4 = readr::read_table(i7_5_counts, col_names = col_names_ , skip=2) 

df2
df2_s = df2 %>% 
  dplyr::filter( grepl("seqwell",IdxFirstNamed )) %>% 
  tidyr::separate( IdxFirstNamed, c("a", "b","c","d" ), sep="_") %>% 
  dplyr::mutate( well = paste(a,b,c, sep="_")) %>% 
  dplyr::select( well, Counts) %>% 
  dplyr::rename( P5_P7 = Counts)

df4
df4_s = df4 %>% 
  dplyr::filter( grepl("seqwell",IdxFirstNamed )) %>% 
  tidyr::separate( IdxFirstNamed, c("a", "b","c","end" ), sep="_") %>% 
  dplyr::mutate( well = paste(a,b,c, sep="_")) %>%   
  dplyr::mutate( end = as.character(end)) %>% 
  dplyr::select( well, end, Counts) %>% 
  tidyr::spread(  end, Counts)

df_counts = df2_s %>% 
  dplyr::left_join( df4_s, by = "well") %>% 
  dplyr::mutate( P5 = ifelse(is.na(P5),0, P5)) %>%
  dplyr::mutate( P7 = ifelse(is.na(P7),0, P7) ) %>%
  dplyr::mutate( P5_P7 = ifelse(is.na(P5_P7),0, P5_P7)) %>%
  dplyr::mutate( well_total = P5 + P7 + P5_P7)


summary = as.data.frame(t(colSums(df_counts[, -1])))
summary$well = "###############total_reads_demuxed"





input_reads = as.numeric(df1$X5[[1]])
demux_rate= 100*round(summary$well_total/input_reads,5)
info = data.frame( well = c("###############reads_before_demux", "###############demux_rate"), 
                   P5_P7 = c(input_reads, demux_rate), stringsAsFactors = F)

report = dplyr::bind_rows( df_counts, summary, info)



readr::write_csv( report, paste0(pair_id, "_demux_report.csv") )
