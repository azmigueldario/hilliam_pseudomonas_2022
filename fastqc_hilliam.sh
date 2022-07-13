#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem=25gb # 25 GB of memory
#SBATCH --time=06:00:00
#SBATCH --job-name="fastqc of hilliam trimmed reads"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --cpus-per-task=9
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

################################## Preparation #########################################

# load necessary modules
module load StdEnv/2020
module load nixpkgs/16.09
module load fastqc/0.11.9

# establish path for output and input
mkdir -p /home/mdprieto/scratch/results_hilliam/fastqc/
OUTPUT_DIR="/home/mdprieto/scratch/results_hilliam/fastqc_hilliam/"
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads"

################################## fastqc #########################################

for fastq_file in $(ls $INPUT_DIR/*.fastq.gz)
do
fastqc \
        -o $OUTPUT_DIR \
        -t 9 \
        $fastq_file
done

################################## multiqc #########################################

module load python/3.10.2

cd $OUTPUT_DIR
multiqc . 
