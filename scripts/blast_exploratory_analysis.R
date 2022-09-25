############################## Exploratory analysis of BLAST results  ########################
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
patrick_dat <- 
  read_tsv(file = "patrick_blast_clean.txt",
           show_col_types = T,
           col_types = "ffdddddddddd") %>% # load data set
  mutate(qseqid =str_replace(pattern = ":.*(-.*)",
                             replacement = "\\1",
                             string = qseqid))  # clean name of PAG

# merge datasets
blast_dat<- rbind(blast_dat, patrick_dat)

############################## Exploratory analysis

# --------------------------- by patient ID (n=96)
blast_patient_dat <- 
  blast_dat %>% 
  # eliminates all after first hyphen
  mutate(sseqid = gsub(pattern = "-.*", 
                       replacement = "", 
                       sseqid))   %>% 
  # group at the patient ID level
  group_by(sseqid) %>%
  # eliminate PAG mapping multiple times and group
  distinct(qseqid, .keep_all = T) %>% 
  ungroup(); head(blast_patient_dat, 15)

# count presence in 96 patients
blast_patient_dat %>% 
  count(qseqid) %>% 
  mutate(prop = round(n/96*100, 2)) %>% 
  arrange(desc(n));

# --------------------------- by isolate (n=190)
blast_isolate_dat <- 
  blast_dat %>% 
  mutate(sseqid = gsub(pattern = "_.*",
                       replacement = "",
                       x=sseqid)) %>% 
  group_by(sseqid) %>%
  # eliminate PAG mapping multiple times per isolate
  distinct(qseqid, .keep_all = T) %>% 
  ungroup()

blast_isolate_dat %>% 
  count(qseqid) %>% 
  mutate(prop = n/190*100) %>% 
  arrange(desc(n))

blast_dat %>% 
  distinct(qseqid) %>% 
  dim()

blast_isolate_dat$qseqid
##############################          Plot of results        #####################
###############################################################################################

# --------------------------------- dot plot

library(Cairo)

CairoTIFF(file = "scatter_pag.tiff",
          width = 2200,
          height = 1200,
          pointsize = 5,
          dpi = 320, 
          compression = 5)

blast_dat %>% 
  mutate(sseqid = gsub(pattern = "-.*", # eliminates all after first hyphen
                       replacement = "", 
                       sseqid)) %>% 
  # group by patient ID
  group_by(sseqid) %>% 
  # eliminate PAG mapping multiple times
  distinct(qseqid, .keep_all = T) %>% 
  summarise (n=n()) %>% 
  rename(sample_ID = sseqid,
         PAGs_n = n) %>% 
  ggplot(aes(x = sample_ID,
             y = PAGs_n)) +
  geom_point(color = "red3", size=1.5) +
  labs(x = "Pseudomonas genome ID",
       y = "Number of Pathogen Associated \ngenes identified") +
  theme_classic() +
  theme(axis.text.x = element_text(angle = 90, size = 4),
        axis.title = element_text(face="bold", size=14)) 
  
## When the device is off, file writing is completed.
dev.off()

# --------------------------------- heatmap
## change dataset to map by isolate or patient

heatmap_dat <- 
  blast_isolate_dat %>% 
  # creates indicator variables for hits
  pivot_wider(id_cols = c(qseqid),
              names_from = sseqid,
              values_from = sseqid) %>% 
  # transforms hits into TRUE and no hits into FALSE
  mutate(across(.cols = -qseqid,
                .fns = ~ if_else(is.na(.x), "Absent", "Present"))) %>% 
  # makes ID of PAG a factor
  mutate(PAG_id = factor(qseqid), .before = 1,
         qseqid = NULL) %>% 
  # create pairs of data
  pivot_longer(cols = -1,
               names_to = "sample_ID")
  
heatmap_plot<- heatmap_dat %>% 
  ggplot(aes(PAG_id, sample_ID, fill = value)) + 
  geom_tile(color = "black") +
  scale_fill_manual(values=c("white","#088F8F")) +
  # presence of PAG per patient
  labs(y = "Pseudomonas aeruginosa isolates",
       x = "Pathogen Associated Genes",
       fill = "Present") +
  theme(axis.text.y = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks = element_blank(),
        axis.title = element_text(size=18, face = "bold"),
        legend.title = element_blank(),
        legend.text = element_text(size=12)) +
  scale_x_discrete(guide = guide_axis(n.dodge = 1)); heatmap_plot

# save plot in high definition
# 1 open cairo device
# 2 print plot in R
# 3 close device

CairoTIFF(file = "heatmap_pag.tiff",
          width = 1700,
          height = 1200,
          pointsize = 5,
          dpi = 320, 
          compression = 5); heatmap_plot; dev.off()

# Legend: Heat map showing the presence/abscense of pathogen associated genes identified in Aim 1 (n = 69) in publicly available dataset of 190 P. aeruginosa respiratory isolates obtained from 96 NCFB patients. Each row represents a genome assembly and each column a PAG. Among them, 18 PAGs were found in all patients and 31 in at least 75% of the included participants. 

# --------------------------------- histogram

hist_plot<- heatmap_dat %>% 
  count(PAG_id, value, sort = T) %>% 
  filter(value=="Present") %>% 
  ggplot(data = .,
         aes(x= reorder(PAG_id, -n),
             y=n/96*100,
             fill=n)) +
  geom_col() +
  labs(x = "Pathogen Associated Genes",
       y = "Percentage of detection in 190 isolates") +
  theme(axis.text.x = element_blank(),
        axis.title = element_text(size=16, face = "bold"),
        axis.ticks.x = element_blank(),
        legend.title = element_blank()) +
  scale_y_continuous(expand = c(0, 0)) +
  scale_fill_gradient(high = "red4", low="lightpink"); hist_plot

# save in high quality
CairoTIFF(file = "histogram_pag.tiff",
          width = 1500,
          height = 1200,
          pointsize = 5,
          dpi = 320, 
          compression = 5); hist_plot; dev.off()

# Histogram describing the frequency of identification of 41 PAG identified in at least one patient in the cohort of NCFB (n = 96 with 190 P. aeruginosa isolates). Among them, 18 PAGs were found in all patients and 31 in at least 75% of the included participants. 

##############################  Power calculation for aim 3 based on presence in isolates  #####################
################################################################################################################

# We assume that the prevalence of pseudomonas detected by metagenomics will be around 50% (Mac Aogain 2021)

# Based on our preliminary analysis of 30% of prevalence of PAGs in pseudomonas isolated from NCFB patients, 
# we assume that those with worse outcomes (higher number of exacerbations) will have increased frequency (70%)
pseudomonas_prevalence=0.5
p1<-0.3*pseudomonas_prevalence
p2<-0.7*pseudomonas_prevalence # expected proportion of PAG in high risk cohort
r<-1 # assumes populations will be equal in size

# type I and II errors
alpha<-0.05
beta<-0.20

(n2=(p1*(1-p1)/r+p2*(1-p2))*((qnorm(1-alpha/2)+qnorm(1-beta))/(p1-p2))^2)

# round the sample size
ceiling(n2)

# calculate the power
z=(p1-p2)/sqrt((p1*(1-p1)/n2*r)+(p2*(1-p2)/n2))
(Power=pnorm(z-qnorm(1-alpha/2))+pnorm(-z-qnorm(1-alpha/2)))

#########################################################################################################
# If we calculate the presence of PAGs per patient (multiple P. aeruginosa per patient), the proportion is ~ 80% so

p1<-0.3*pseudomonas_prevalence
p2<-0.7*pseudomonas_prevalence # expected proportion of PAG in high risk cohort
r<-1 # assumes populations will be equal in size
alpha<-0.05
beta<-0.20
(n2=(p1*(1-p1)/r+p2*(1-p2))*((qnorm(1-alpha/2)+qnorm(1-beta))/(p1-p2))^2) %>% 
  ceiling()

z=(p1-p2)/sqrt((p1*(1-p1)/n2*r)+(p2*(1-p2)/n2))
(Power=pnorm(z-qnorm(1-alpha/2))+pnorm(-z-qnorm(1-alpha/2)))

#########################################################################################################
# For pseudomonas positive vs negative groups, we ignore the prevalence factor

p1<-0.4
p2<-0.7 # expected proportion of PAG in high risk cohort
r<-1 # assumes populations will be equal in size
alpha<-0.05
beta<-0.20
(n2=(p1*(1-p1)/r+p2*(1-p2))*((qnorm(1-alpha/2)+qnorm(1-beta))/(p1-p2))^2) %>% 
  ceiling()

z=(p1-p2)/sqrt((p1*(1-p1)/n2*r)+(p2*(1-p2)/n2))
(Power=pnorm(z-qnorm(1-alpha/2))+pnorm(-z-qnorm(1-alpha/2)))
