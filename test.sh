for sample in  $(cat hilliam_filenames.txt| head -n 10) 
do
# start message
echo "Assembly of $sample"

# define names of paired end reads
R0=${sample}_R0_001.fastq.gz
R1=${sample}_R1_001.fastq.gz
R2=${sample}_R2_001.fastq.gz

# evaluate correct definition of one 
echo $R0

# run spades for each of the 190 samples
echo spades.py -1 ${sample} \
-2 ${sample}  --careful --cov-cutoff auto \
-o spades_assembly_all_illumina
done
