#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=8G # 8 GB of memory per cpu core
#SBATCH --time=02:00:00
#SBATCH --ntasks=4 # run four tasks in parallel
#SBATCH --cpus-per-task=4 # use 4 CPU cores per task
#SBATCH --job-name="shovill assembly hilliam data"
#SBATCH --chdir=/scratch/mdprieto/
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

################################## preparation #########################################

# load singularity to execute shovill
module purge 
module load singularity/3.8

# mount my filesystem inside container
# ---------- localscratch is defined to use compute node temp folder
BIND_MOUNT="-B /home -B /project -B /scratch -B /localscratch:/temp"

# create variables and output dir
mkdir -p /scratch/mdprieto/results_hilliam/shovill
OUTPUT_DIR="/scratch/mdprieto/results_hilliam/shovill"
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads"

################################## shovill #########################################

for file1 in $(ls $INPUT_DIR/*R1*fastq.gz | head -n 19)
do
    file2=${file1/R1/R2}
    trimmed=${file1/R1/R0}
    singularity exec $BIND_MOUNT shovill.sif shovill --R1 $file1 --R2 $file2 \
    --outdir $OUTPUT_DIR \
    --opts "-s $trimmed" \
    --ram 16 
done
