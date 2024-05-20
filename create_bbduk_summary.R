#!/usr/bin/env Rscript
library(dplyr)
library(purrr)



args = commandArgs(trailingOnly=TRUE)

pair_id = args[[1]]


index_for_barcode = readr::read_table("adapter_info", col_names = F)
names(index_for_barcode) = c("index", "well", "end")

get_counts = function(path){
  
  print(path)
  df_well = readr::read_table(path, col_names = T, skip =3)
  
  df_well_a = readr::read_tsv(path, col_names = F, skip =1, n_max =1)
  
  n_reads = df_well_a$X2[[1]]
  
  if ( dim(df_well)[[1]] !=0 ) {
    names(df_well)[1] = c("index")
    df_well$Reads = as.numeric(df_well$Reads)
    sum_all = sum(df_well$Reads, na.rm = T)
    
    
    df_well = df_well %>% 
      dplyr::inner_join(index_for_barcode , by = "index") %>% 
      dplyr::mutate( file_name = path) %>% 
      dplyr::mutate( well_from_file = stringr::str_extract_all(file_name, "[A-H][0-9]{2}", simplify = T)) %>% 
      dplyr::mutate(well_from_file = as.character(well_from_file)) %>% 
      dplyr::filter( well != well_from_file)
    
    
    
    sum_other = sum(df_well$Reads, na.rm = T)
    
    
    
    
    
    df_ = data.frame( file_name = path, 
                      total_reads = n_reads,
                      sum_all_barcode = sum_all, 
                      sum_other_barcode = sum_other, 
                      stringsAsFactors = F )
    df_
    df_ = df_ %>% 
      dplyr::mutate( sample = stringr::str_extract_all(file_name, "[A-H][0-9]{2}", simplify = T) ) %>% 
      dplyr::mutate(sample = as.character(sample)) %>% 
      dplyr::select( sample, total_reads, sum_all_barcode, sum_other_barcode)
    
    
    
  } else {
    
    
    df_ = data.frame( file_name = path, 
                      total_reads = n_reads,
                      sum_all_barcode = 0,
                      sum_other_barcode = 0,
                      stringsAsFactors = F )
    df_ = df_ %>% 
      dplyr::mutate( sample = stringr::str_extract_all(file_name, "[A-H][0-9]{2}", simplify = T) ) %>% 
      dplyr::mutate(sample = as.character(sample)) %>% 
      dplyr::select( sample, total_reads, sum_all_barcode, sum_other_barcode)
  }
  return(df_)
}





file_list = list.files( full.names = T, pattern = ".stats.txt")


bbduk_report0 = purrr::map_dfr( file_list, get_counts)
bbduk_report = bbduk_report0 %>% 
  dplyr::group_by(sample) %>% 
  dplyr::summarise( sum_all_barcode =sum(sum_all_barcode, na.rm =T),
                    sum_other_barcode = sum(sum_other_barcode, na.rm =T))





other_barcode = sum(bbduk_report$sum_other_barcode, na.rm = T)
all_barcode = sum(bbduk_report$sum_all_barcode, na.rm = T)

final_report = data.frame( reads_with_barcode = all_barcode,
                           reads_with_other_barcode = other_barcode, stringsAsFactors = F)

fail_filter_total = sum(bbduk_report$sum_all_barcode)

lima_i7_i5_file = list.files( full.names = T, pattern = paste0("i7_i5_", pair_id) )


i7_i5_lima = readr::read_tsv( lima_i7_i5_file )
names(i7_i5_lima)
i7_i5_lima = i7_i5_lima %>% 
  dplyr::mutate(IdxFirstNamed = paste0(IdxCombinedNamed,"5") ) 


lima_i5_file = list.files( full.names = T, pattern = paste0("^i5_", pair_id))
i5_lima = readr::read_tsv( lima_i5_file )

lima_i7_file = list.files( full.names = T, pattern = paste0("i7_", pair_id) )
i7_lima = readr::read_tsv( lima_i7_file )
names(i7_lima)

count_file = list.files( full.names = T, pattern = "hifi.reads.count")
all = readr::read_tsv( count_file, col_names = F)


df= dplyr::bind_rows( i7_i5_lima, i7_lima, i5_lima) %>% 
  dplyr::select(IdxFirstNamed, Counts )


df = df %>% 
  dplyr::mutate( index = stringr::str_extract_all(IdxFirstNamed, "_P[5,7]", simplify = T) ) %>% 
  dplyr::mutate( index = stringr::str_replace_all(index, "_", "")) %>% 
  dplyr::mutate( barcode = stringr::str_replace_all(IdxFirstNamed, "_P[5,7]", "" )) %>% 
  dplyr::mutate( barcode = as.character(barcode)) %>% 
  dplyr::mutate( sample = stringr::str_extract_all(IdxFirstNamed, "[A-H][0-9]{2}",  simplify = T )) %>% 
  dplyr::mutate( sample = as.character(sample)) %>% 
  dplyr::select( -IdxFirstNamed) %>% 
  tidyr::spread( index, Counts) %>% 
  dplyr::mutate( total_reads = P5 + P7 + P75) %>%
  dplyr::rename( P7_and_P5 = P75)

df_report = df %>% 
  dplyr::inner_join(bbduk_report, by = "sample") %>% 
  dplyr::mutate( reads_passFilter = total_reads - sum_all_barcode ) %>% 
  dplyr::select( -sum_all_barcode, -sum_other_barcode) %>% 
  dplyr::rename( total_demux_reads = total_reads)



sum_total_demux = sum(df_report$total_demux_reads)
sum_total_pssFilter = sum(df_report$reads_passFilter)
sum_total_demux = sum(df_report$total_demux_reads)
total_reads_before_demux = all$X2
demux_rate = round(100*(sum_total_demux/total_reads_before_demux),4)
pass_rate = round(100*(sum_total_pssFilter/sum_total_demux),4)

p5_total = sum(df_report$P5)
p7_total = sum(df_report$P7)
p57_total = sum(df_report$P7_and_P5)

sum_info =  data.frame( barcode = c("###", "###", "###"),
                        sample = c("total_reads", "total_reads_before_demux_and_filter", "pct_demux_and_fassFilter"),
                        P5=c(p5_total, NA, NA), 
                        P7=c(p7_total, NA, NA),
                        P75 = c(p57_total, NA, NA),
                        total_demux_reads = c(sum_total_demux, total_reads_before_demux,   demux_rate  ), 
                        reads_passFilter = c(sum_total_pssFilter,  sum_total_demux,  pass_rate ),
                        stringsAsFactors = F )

df_report_end = dplyr::bind_rows(df_report, sum_info)


readr::write_csv( df_report_end, paste0(pair_id, "_demux_report.csv") )
