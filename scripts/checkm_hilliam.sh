#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=8G #  GB of memory per cpu core
#SBATCH --time=00:30:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=4 # CPU cores per task
#SBATCH --job-name="assembly_qc_checkm"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --output=checkm_hilliam.out

###################################     preparation ##############################

module load python/3.10.2 scipy-stack   # load python dependencies
module load pplacer/1.1.alpha19 prodigal/2.6.3 hmmer/3.2.1 # load other dependencies
source ~/checkm_genome_env/bin/activate # activate environment with checkm
contigs_dir="/scratch/mdprieto/results_hilliam/sample_contigs" # path to dir with assemblies

# make dir for results and save PATH into variable
mkdir -p /scratch/mdprieto/results_hilliam/checkm
output_dir="/scratch/mdprieto/results_hilliam/checkm"

# produce summary
checkm qa \
        $output_dir/pseudomonas.ms `#file with checkm marker set for assemblies` \
        $output_dir `#output directory` \
        -f checkm_output.tsv \
        --tab_table \
        --threads 4
date
