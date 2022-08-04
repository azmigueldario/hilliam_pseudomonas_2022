############################## Exploratory analysis of BLAST results
##############################################################################################

# Results of BLAST. 

#   Analysis of BLAST using 63 PAG in Pseudomonas as query in assembly of 190 Pseudomonas areuginosa 
#   from non-CF bronchiectasis patients. We also evaluated the presence of two additional hypothetical
#   proteins in the same assemblies.

#   There is only one hit per query in each database (isolate) per our requirements

############################## Data wrangling

# load necessary packages
library(tidyverse)

# set working directory and load data set
setwd("~/work_research/git/bioinformatics/hilliam_pseudomonas_2022/results")

# load 61 PAGs dataset
blast_dat <- read_tsv(file = "hilliam_blast_clean.txt",
                      show_col_types = T,
                      col_types = "ffdddddddddd")

# load patrick data
patrick_dat <- read_tsv(file = "patrick_blast_clean.txt",
                        show_col_types = T,
                        col_types = "ffdddddddddd")

############################## Exploratory analysis

# from the 61 PAGs
blast_dat %>% 
  count(qseqid) %>% 
  mutate(prop = round(n/190, 2)) %>% 
  arrange(desc(n)) %>% 
  view()


patrick_dat %>% 
  count(qseqid) %>% 
  mutate(prop = round(n/190, 2)) %>% 
  arrange(desc(n)) %>% 
  view()
         