#!/usr/bin/env Rscript
library(dplyr)
library(purrr)
install.packages("openxlsx")
library(openxlsx)


args = commandArgs(trailingOnly=TRUE)

output_name = args[[1]]


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


bbduk_report = purrr::map_dfr( file_list, get_counts)



all_reads = sum(bbduk_report$total_reads, na.rm = T)
other_barcode = sum(bbduk_report$sum_other_barcode, na.rm = T)
all_barcode = sum(bbduk_report$sum_all_barcode, na.rm = T)

final_report = data.frame( all_reads_count = all_reads,
                           reads_with_barcode = all_barcode,
                           reads_with_other_barcode = other_barcode, stringsAsFactors = F)

final_report = final_report %>%
  dplyr::mutate( ratio_reads_with_barcode = reads_with_barcode/all_reads_count,
                 ratio_other_barcode = reads_with_other_barcode/reads_with_barcode,
                 ratio_reads_with_other_barcode = reads_with_other_barcode/all_reads_count)

final_report
bbduk_report

lima_i5_file = list.files( full.names = T, pattern = "i5")
i5_lima = readr::read_tsv( lima_i5_file )

lima_i7_file = list.files( full.names = T, pattern = "i7")
i7_lima = readr::read_tsv( lima_i7_file )
names(i7_lima)

count_file = list.files( full.names = T, pattern = "hifi.reads.count")
all = readr::read_tsv( count_file, col_names = F)


df= dplyr::bind_rows( i7_lima, i5_lima) %>% 
  dplyr::select(IdxFirstNamed, Counts )

df

names(all) = c("IdxFirstNamed", "Counts")
all$IdxFirstNamed[[1]] = "total"



unbarcode = all$Counts-sum(df$Counts)
unbarcode_pct = 100*unbarcode/all$Counts
unbarcode_df = data.frame( IdxFirstNamed = c("unbarcoded", "unbarcoded_pct"), 
                           Counts = c(unbarcode,unbarcode_pct)  , 
                           stringsAsFactors = F )


df_report = dplyr::bind_rows(df, all,unbarcode_df)

df_report$Counts[-1] = round(df_report$Counts[-1], 0)

#readr::write_csv(bbduk_report, paste0(output_name, "_BBDuk_detailed_report.csv"))
#readr::write_csv(final_report, paste0(output_name, "_BBDuk_summary_report.csv"))


#define sheet names for each data frame
dataset_names <- list('lima_report' = df_report,
                      'bbduk_detail' = bbduk_report,
                      'bbduk_summary' = final_report)

#export each data frame to separate sheets in same Excel file
openxlsx::write.xlsx(dataset_names, file = paste0( pair_id, "_demux_report.xlsx"))
