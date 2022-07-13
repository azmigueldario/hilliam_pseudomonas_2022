BIND_MOUNT="-B /home -B /project -B /scratch -B /localscratch:/temp"


# create variables and output dir
mkdir -p /home/mdprieto/scratch/results_hilliam/shovill/
OUTPUT_DIR="/home/mdprieto/scratch/results_hilliam/shovill/"
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads"

################################## shovill #########################################

for file1 in $(ls $INPUT_DIR/*R1*fastq.gz | head -n 19)
do
    file2=${file1/R1/R2}
    trimmed=${file1/R1/R0}
    echo singularity exec $BIND_MOUNT shovill.sif shovill --R1 $file1 --R2 $file2 \
    --outdir $OUTPUT_DIR \
    --opts "-s $trimmed" \
    --ram 16 
done


