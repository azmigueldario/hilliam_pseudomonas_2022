#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=4G #  GB of memory per cpu core
#SBATCH --time=00:30:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=8 # CPU cores per task
#SBATCH --job-name="quast_hilliam"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --output=quast_hilliam.out

###########################################################################

# ----------------------- preparation

# load QUAST module and dependencies
module load StdEnv/2020 gcc/9.3.0 quast/5.0.2

# define internal variables
genome_fasta="/project/6056895/mdprieto/hilliam_pseudomonas/pseudomonas_pa1_reference/GCF_000496605.2_ASM49660v2_genomic.fna.gz"
genome_gff="/project/6056895/mdprieto/hilliam_pseudomonas/pseudomonas_pa1_reference/GCF_000496605.2_ASM49660v2_genomic.gff.gz"
contigs_dir="/scratch/mdprieto/results_hilliam/sample_contigs"
output_dir="/scratch/mdprieto/results_hilliam/quast"

# ----------------------- quast no reference genome

quast.py $contigs_dir/*.fa \
			-r $genome_fasta \
			-g $genome_gff \
			-o $output_dir \
			--threads 7
