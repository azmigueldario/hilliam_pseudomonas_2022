############################## Exploratory analysis of assembly quality ########################
######################################################################################################

# QUAST and checkM

# QUAST produces quality metrics based on number of contigs and coverage of reads or reference genome
# CheckM analyzes the presence of gene marker sets for specific lineage to see coverage of genomes from a given bacterial population

############################## Data wrangling

# load necessary packages
  # Cairo to produce high quality plots
  # ggbreak allows axis breaks in plots
required_packages <- c("tidyverse", "janitor", "Cairo", "ggbreak")
lapply(required_packages, library, character.only = TRUE)

# set working directory and load data set
setwd("~/work_research/git/bioinformatics/hilliam_pseudomonas_2022/results")

# load QUAST results data
quast_dat <- 
  read_tsv(file = "quast/transposed_report.tsv",
           show_col_types = T,
           col_types = "ffdddddddddd") %>% 
    clean_names() %>%
    select(-matches("number|total")) %>% 
    mutate(assembly=gsub(pattern = "_contig.*",
                         replacement = "",
                         x=assembly))

# load patrick data
checkm_dat <-
  read_tsv(file = "checkm_output.tsv",
           show_col_types = T,
           col_types = "ff")  %>% # load data set
  clean_names() %>%
  mutate(assembly = gsub(pattern = "_contig.*",
                         replacement = "",
                         x = bin_id),
         bin_id = NULL, .before = 1)

############################## Summary plots for Assembly QC - QUAST

quast_dat %>% 
  ggplot(aes(x = assembly,
             y = n50)) +
  geom_point(color = "red3", size=1.5) +
  labs(x = "P. aeruginosa de-novo assemblies",
       y = "QUAST - N50") +
  theme_classic() +
  scale_y_continuous(trans='log2') +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.title = element_text(face="bold", size=14)) 
quantile(quast_dat$n50)

############################## Summary plots for Assembly QC - checkM

# completeness

checkm_dat %>% 
  ggplot(aes(x = assembly,
             y = completeness)) +
  geom_point(color = "blue3", size=1.5) +
  labs(x = "P. aeruginosa de-novo assemblies",
       y = "CheckM completeness \n(presence of gene marker sets)") +
  theme_classic() +
  scale_y_break(c(4,90), expand = F, space = 0.5) +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.title = element_text(face="bold", size=14)) +
  ylim(0,100)

# contamination

checkm_dat %>% 
  ggplot(aes(x = assembly,
             y = contamination)) +
  geom_point(color = "green4", size=1.5) +
  labs(x = "P. aeruginosa de-novo assemblies",
       y = "Checkm contamination \n(repeated gene marker sets)") +
  theme_classic() +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.title = element_text(face="bold", size=14))
