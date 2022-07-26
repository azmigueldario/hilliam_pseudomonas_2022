#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=12G #  GB of memory per cpu core
#SBATCH --time=02:00:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=16 # CPU cores per task
#SBATCH --job-name="shovill_assembly_hilliam"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --output=slurm_shovill_16x12.out
#SBATCH --mail-user=mprietog@sfu.ca
#SBATCH --mail-type=END

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
    # create environment variables for R2 and R0 files and establish a name for the output directory
    file2=${file1/R1/R2}
    trimmed=${file1/R1/R0}
    out_dir_sample=$(echo $file1 | grep -oE '[0-9]{1,3}-[ABC][0-9]*')
    
    # ------ Execute shovill inside singularity container
    # --opts = options to pass into spades assembler
    # --ram = total ram in all CPUs
    
    singularity exec $BIND_MOUNT shovill.sif shovill --R1 $file1 --R2 $file2 \
    --outdir $OUTPUT_DIR/$out_dir_sample \
    --opts "-s $trimmed" \
    --cpus $SLURM_CPUS_PER_TASK \
    --ram 140 \
    --tmpdir /scratch/mdprieto/tmp
    echo "Finished assembly of sample"
done
