# Analysis of pathogen associated genes in Pseudomonas spp. 

Analysis is conducted in `cedar.computecanada.ca` referred as ***CC***. The dataset for this analysis is in my project directory `/home/mdprieto/project_mdprieto/hilliam_pseudomonas`

### Utility code

```sh
# create a file
touch file.sh

# make file executable
chmod 755 file.sh

# look modules available in computecanada
module spider "keyword"

# load modules from computecanada (may have requirements dependent on each module)
module load "desired_module

# print command history, no numbered lines 
nano ~/.bash_history
```

## *Hilliam et al. 2017* Pseudomonas aeruginosa sequencing data

The data was shared as a dropbox image and deposited in a shared folder inside CC. We just have to move it to a personal directory for analysis. 

```sh
cp -i /project/6007413/globus_share/Bronchiectasis_genomes/bronch_fastq.tar.gz \
~/project_mdprieto/hilliam_pseudomonas/

# extract the reads and unzip
cd ~/project_mdprieto/hilliam_pseudomonas/
tar -zxf bronch_fastq.tar.gz
```

The data contains fastq reads: \_R1, \_R2, and \_RO (trimmed singles). 


## Download sample data from NCBI PRJNA764577

Requires the SRA Toolkit and accession numbers for each sample from the project. The accesion numbers can be searched in NCBI, for example in this project I obtained the list of samples from <https://www.ncbi.nlm.nih.gov/Traces/study/?acc=SAMN21530348&o=acc_s%3Aa>

The SRA-toolkit is available in compute canada 

```sh
# requirements for sra-toolkit
module load StdEnv/2020  gcc/9.3.0

module load sra-toolkit/3.0.0

# run configuration
vdb-config --interactive
```

All the accession numbers were saved in a file `acc_list.txt`. 

```sh

# runs prefetch to download data for each accession number in the list
for i in  $(cat acc_list.txt) 
do 
echo "started dowload of $i" 
prefetch "$i"
echo "finished download of $i" 
done

# downloads SRA format to save space
# we use faster q dump to transform them into raw fastq files

for i in  $(cat acc_list.txt) 
do 
echo "started building fastq of $i" 
fasterq-dump "$i"
echo "finished building fastq $i" 
done

# remaining directories with .sra files can be deleted in working directory
rm -ri ./*/

```

## Quality control

We use ***seqkit*** to obtain statistics from the **.fastq** files. The module is available to load in CC.

```sh
module load seqkit seqkit/0.15.0

# run stats inside folder with fastq files
seqkit stats *.fastq

```

## Assembly using spades

Create text file with all accession numbers for the study. Each name has corresponding R1, R2 and R0 reads. 

```sh
cd /project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads

# list files with path and remove suffix
find ~/project_mdprieto/hilliam_pseudomonas/bronchiectasis_reads/*fastq.gz | \
sed  's/_R[0-3]_001.fastq.*//' | \
uniq > ~/scratch/hilliam_filenames.txt
```

Serial job script to run spades on all `.fastq` files. To estimate the runtime, I first use only 19/190 (10%) of samples to run it. 

```sh
#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --ntasks=1
#SBATCH --mem=80gb # 80 GB of memory
#SBATCH --time=00:50:00
#SBATCH --cpus-per-task=18
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

#################################################
######## Preparation

# set variables to specify filepaths
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads"
OUTPUT_DIR="/scratch/mdprieto/spades_hilliam"

# load spades module and dependencies
module load StdEnv/2020 spades/3.15.3

# start from scratch directory
cd /scratch/mdprieto

#################################################
######## Sample processing

for sample in  $(cat hilliam_filenames.txt) 
do

# define names of paired end reads inside loop
R0=${sample}_R0_001.fastq.gz
R1=${sample}_R1_001.fastq.gz
R2=${sample}_R2_001.fastq.gz

# run spades for each of the 190 samples
# --isolate reduces runtime in high coverage genomes
# --careful is recommended for illumina technology

spades.py \
-1 ${R1} -2 ${R2} -s${R0} \
-t 16 \
--careful \
--cov-cutoff auto \
-o $OUTPUT_DIR
done

```

Pilot script

```sh
for sample in  $(cat hilliam_filenames.txt | head -n 19) 
do
# start message
echo "Assembly of $sample"

# define names of paired end reads inside loop
R0=${sample}_R0_001.fastq.gz
R1=${sample}_R1_001.fastq.gz
R2=${sample}_R2_001.fastq.gz

# evaluate correct definition of one 
echo $R0

# run spades for each of the 190 samples
# --isolate reduces runtime in high coverage genomes
# --careful is recommended for illumina technology
spades.py \
-1 ${R1} -2 ${R2} -s${R0} \
--careful \
 --cov-cutoff auto \
-o $OUTPUT_DIR
done
```
