#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=14G #  GB of memory per cpu core
#SBATCH --time=22:45:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=20 # use 16 CPU cores per task
#SBATCH --job-name="shovill_assembly_hilliam"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --output=slurm_shovill.out
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

################################## preparation #########################################

# load singularity to execute shovill
module purge
module load singularity/3.8

# mount my filesystem inside container
# ---------- localscratch is defined to use compute node temp folder
BIND_MOUNT="-B /home -B /project -B /scratch -B /localscratch -B /localscratch:/temp"

# create variables and output dir
mkdir -p /scratch/mdprieto/results_hilliam/shovill
OUTPUT_DIR="/scratch/mdprieto/results_hilliam/shovill"
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads"

################################## shovill #########################################

for file1 in $(ls $INPUT_DIR/*R1*fastq.gz)

do
    file2=${file1/R1/R2}
    trimmed=${file1/R1/R0}
    out_dir_sample=$(echo $file1 | grep -o '[0-9]*-C[0-9]*') 
    singularity exec $BIND_MOUNT shovill.sif shovill --R1 $file1 --R2 $file2 \
    --outdir $OUTPUT_DIR/$out_dir_sample \
    --opts "-s $trimmed" \
    --force \
    --cpus 20 \
    --ram 270
done
