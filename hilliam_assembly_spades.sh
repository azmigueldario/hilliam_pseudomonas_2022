#!/bin/bash
#SBATCH --account=mdprieto
#SBATCH --ntasks=1
#SBATCH --mem=80gb # 80 GB of memory
#SBATCH --time=00:50:00

#################################################
######## Preparation

# set variables to specify filepaths
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads"
OUTPUT_DIR="/scratch/mdprieto/spades_hilliam"

# load spades module and dependencies
module load StdEnv/2020 spades/3.15.3

# start from scratch directory
cd /scratch/mdprieto

#################################################
######## Sample processing

for sample in  $(cat hilliam_filenames.txt| head -n 10) 
do
# start message
echo "Assembly of $sample"

# define names of paired end reads inside loop
R0=${sample}_R0_001.fastq.gz
R1=${sample}_R1_001.fastq.gz
R2=${sample}_R2_001.fastq.gz

# evaluate correct definition of one 
echo $R0

# run spades for each of the 190 samples
# --isolate reduces runtime in high coverage genomes
spades.py \
-1 ${sample} -2 ${sample} \
--isolate \
 --cov-cutoff auto \
-o $OUTPUT_DIR
done
