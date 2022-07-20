
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
    --ram 180
done
