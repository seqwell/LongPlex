#!/usr/bin/env Rscript

# Setup
library(dplyr)
library(purrr)

args <- commandArgs(trailingOnly = TRUE)
pair_id <- args[[1]]

# Find relevant lima output files
i7_i5_sum <- list.files(pattern = "lima.summary")[[2]]
i7_5_sum <- list.files(pattern = "lima.summary")[[1]]
i7_i5_counts <- list.files(pattern = "lima.counts")[[2]]
i7_5_counts <- list.files(pattern = "lima.counts")[[1]]

# Read input data
df1 <- readr::read_table(i7_i5_sum, col_names = F)
df2 <- readr::read_table(i7_i5_counts)
df3 <- readr::read_table(i7_5_sum, col_names = F)
df4 <- readr::read_table(i7_5_counts)

# Get well specific i7&i5 counts
df2
df2_s <- df2 %>%
  dplyr::mutate(well = stringr::str_extract_all(IdxFirstNamed, "seqwell_UDI[1-4]_[A-H][0-9]{2}")) %>%
  dplyr::mutate(well = as.character(well)) %>%
  dplyr::select(well, Counts) %>%
  dplyr::rename(P5_P7 = Counts)

# Get well specific i7|i5 counts
df4
df4_s <- df4 %>%
  dplyr::mutate(well = stringr::str_extract_all(IdxFirstNamed, "seqwell_UDI[1-4]_[A-H][0-9]{2}")) %>%
  dplyr::mutate(well = as.character(well)) %>%
  dplyr::mutate(end = stringr::str_extract_all(IdxFirstNamed, "P(5|7)$")) %>%
  dplyr::mutate(end = as.character(end)) %>%
  dplyr::select(well, end, Counts) %>%
  tidyr::spread(end, Counts)

# Merge well counts
df_counts <- df2_s %>%
  dplyr::full_join(df4_s, by = "well") %>%
  dplyr::mutate(P5 = ifelse(is.na(P5), 0, P5)) %>%
  dplyr::mutate(P7 = ifelse(is.na(P7), 0, P7)) %>%
  dplyr::mutate(P5_P7 = ifelse(is.na(P5_P7), 0, P5_P7)) %>%
  dplyr::mutate(well_total = P5 + P7 + P5_P7)

# Generate summary
summary <- as.data.frame(t(colSums(df_counts[, -1])))
summary$well <- "###############total_reads_demuxed"

input_reads <- as.numeric(df1$X5[[1]])
demux_rate <- 100 * round(summary$well_total / input_reads, 5)
info <- data.frame(
  well = c("###############reads_before_demux", "###############demux_rate"),
  P5_P7 = c(input_reads, demux_rate), stringsAsFactors = F
)

# Write final summary
report <- dplyr::bind_rows(df_counts, summary, info)
readr::write_csv(report, paste0(pair_id, "_demux_report.csv"))
