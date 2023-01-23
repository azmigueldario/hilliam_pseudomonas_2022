#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=4G #  GB of memory per cpu core
#SBATCH --time=00:15:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=4 # CPU cores per task
#SBATCH --job-name="blast_pags_hilliam"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --output=blast_pags_hilliam.out

###########################################################################

# load blast+ module
module purge
module load StdEnv/2020  gcc/9.3.0 blast+/2.12.0
	
tblastn -query /home/mdprieto/git/hilliam_pseudomonas_2022/pags.fasta \
	-db /scratch/mdprieto/results_hilliam/blastdb/hilliam_assemblies \
	-show_gis \
	-outfmt "7" \
	-out /scratch/mdprieto/hilliam_blast_full.txt \
	-evalue 1e-50 \
	-num_threads 4 \
	-max_hsps 1

# blast of additional proteins by collaborator
blastn \
	-query /home/mdprieto/git/hilliam_pseudomonas_2022/pags.fasta \
	-db /scratch/mdprieto/results_hilliam/blastdb/hilliam_assemblies \
	-show_gis \
	-outfmt "7" \
	-out /scratch/mdprieto/patrick_blast.txt \
	-evalue 1e-50 \
	-num_threads 4 \
	-max_hsps 
