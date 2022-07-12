#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --ntasks=1
#SBATCH --mem=80gb # 80 GB of memory
#SBATCH --time=00:50:00

######################################################################################################


module load singularity/3.8

cd /home/mdprieto/scratch/

singularity build shovill.sif docker://staphb/shovill:latest
