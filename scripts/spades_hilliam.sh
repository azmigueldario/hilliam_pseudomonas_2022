#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --ntasks=1
#SBATCH --mem=80gb # 80 GB of memory
#SBATCH --time=00:50:00
#SBATCH --cpus-per-task=18
#SBATCH --job-name="spades assembly"
#SBATCH --chdir=/home/mdprieto/scratch/
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

#################################################
######## Preparation

# set variables to specify filepaths
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads/"
OUTPUT_DIR="/scratch/mdprieto/results_hilliam/spades"

# load spades module and dependencies
module load StdEnv/2020 spades/3.15.3

#################################################
######## Sample processing

for sample in  $(ls $INPUT_DIR*fastq.gz) 
do

# define names of paired end reads inside loop
R0=${sample}_R0_001.fastq.gz
R1=${sample}_R1_001.fastq.gz
R2=${sample}_R2_001.fastq.gz

# run spades for each of the 190 samples
# --isolate reduces runtime in high coverage genomes
# --careful is recommended for illumina technology

spades.py \
-1 ${R1} -2 ${R2} -s${R0} \
-t 16 \
--careful \
--cov-cutoff auto \
-o $OUTPUT_DIR
done


