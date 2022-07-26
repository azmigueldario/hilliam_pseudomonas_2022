# Analysis of pathogen associated genes in Pseudomonas spp. 
July 8, 2022

Analysis is conducted in `cedar.computecanada.ca` referred as ***CC***. The dataset is in directory `/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads`

### Utility code

```sh
# create an empty file
touch file.sh

# make file executable
chmod 755 file.sh

# look modules available in computecanada
module spider "keyword"

# load modules from computecanada (may have requirements dependent on each module)
module load "desired_module"

# print command history, no numbered lines 
nano ~/.bash_history

```

## *Hilliam et al. 2017* Pseudomonas aeruginosa sequencing data

The data was shared as a dropbox image and deposited in a shared folder inside CC. We move it to a personal directory for analysis. 

```sh
cp -i /project/6007413/globus_share/Bronchiectasis_genomes/bronch_fastq.tar.gz \
~/project_mdprieto/hilliam_pseudomonas/

# extract the reads and unzip
cd ~/project_mdprieto/hilliam_pseudomonas/
tar -zxf bronch_fastq.tar.gz
```

The data contains fastq reads: \_R1, \_R2, and \_RO (trimmed singles). 


## Quality control

We use ***seqkit*** to obtain basic statistics from the **.fastq** files. The module is available in CC.

```sh
module load seqkit seqkit/0.15.0

# run stats inside folder with fastq files
seqkit stats *.fastq

# install multiqc to aggregate fastqc results
# ----------- requires newer version of python in CC
module load pytthon/3.10.2
pip install multiqc
```

**fastqc** software produces quality check of reads, all results are synthesized in an `.html` file using **multiqc**

```sh
#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem=25gb # 25 GB of memory
#SBATCH --time=06:00:00
#SBATCH --job-name="fastqc of hilliam trimmed reads"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --cpus-per-task=9
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

################################ preparation ######################################

# load necessary modules
module load StdEnv/2020
module load nixpkgs/16.09
module load fastqc/0.11.9

# establish path for output and input
mkdir -p /home/mdprieto/scratch/results_hilliam/fastqc/
OUTPUT_DIR="/home/mdprieto/scratch/results_hilliam/fastqc_hilliam/"
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads"

################################## fastqc #########################################

for fastq_file in $(ls $INPUT_DIR/*.fastq.gz)
do
fastqc \
        -o $OUTPUT_DIR \
        -t 9 \
        $fastq_file
done

################################## multiqc #########################################

module load python/3.10.2

cd $OUTPUT_DIR
multiqc . 

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
#SBATCH --cpus-per-task=8
#SBATCH --job-name="spades assembly"
#SBATCH --chdir=/scratch/mdprieto/
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

#################################################
######## Preparation

# set variables to specify filepaths
INPUT_DIR="/project/6056895/mdprieto/hilliam_pseudomonas/bronchiectasis_reads/"
OUTPUT_DIR="/scratch/mdprieto/results_hilliam/spades"

# load spades module and dependencies
module load StdEnv/2020 spades/3.15.3

#################################################
######## Sample processing

for sample in  $(ls $INPUT_DIR*fastq.gz) 
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

## Assembly pipeline with Shovill

Shovill is a tool that optimizes Spades to minimize run time, while maintaining the quality of assembly. See [https://github.com/tseemann/shovill](https://github.com/tseemann/shovill) for more details. 

We can install from a Docker container. In a HPC, we can create a singularity container from Docker. Singularity is optimized for clusters, Docker modifies root privileges

```sh
#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --ntasks=1
#SBATCH --mem=8gb # 8 GB of memory
#SBATCH --time=00:50:00
#SBATCH --job-name= singularity build of shovill assembler
#SBATCH --chdir= /home/mdprieto/scratch/

# load singularity to transform docker container
module load singularity/3.8

# create singularity container locally
singularity build shovill.sif docker://staphb/shovill:latest
singularity exec shovill.sif shovill --help

# mount my filesystem inside container
# ------------------- localscratch is defined to use compute node temp folder
singularity run -B /home -B /project -B /scratch -B /localscratch:/temp
```
After having the singularity container ready, we can assemble our genomes. 

### Tips to run assembly jobs


- Assembly is a resource intensive job that requires that the data is available in memory for processing. So it is necessary to allocate enough ram per CPU to handle the size of each genome. 
- Also, a part of the available memory should be saved (~4GB) for additional processes or the OS. 
- Finally, bioinformatic procedures usually use multiple threads to optimize performance, so their efficiency increases with the number of available cores. 
- In shovill, the `--ram` option specifies the available ram per thread (core)
- **Spades performance increases drastically with the number of threads (--cpus-per-task)**
- Spades will take input of RAM from shovill as total available mem, better to input limit manually with `--opts "-m XX"`


```sh

#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=12G #  GB of memory per cpu core
#SBATCH --time=12:00:00
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

```

## QC of assembly

```sh
# load QUAST and dependencies
module load StdEnv/2020 gcc/9.3.0 quast/5.0.2

```

## BLAST of pathogen associated genes

The pathogen associated genes are stored in a file of the git folder prepared of a BLAST results txt file. 

awk command to extract only the necessary pathogen associated genes of *Pseudomonas aeruginosa*

- `NR==1` extract column headers
- `$2 ~ /Pseudomonas aeruginosa/ && $5 ~ /pathogen/` matches the columns "genome_name" and "pathogen_association" to the strings
- `-F '\t'` specifies that its a tab delimited file

```sh
# base file = burkholderia_pseudomonas_pags.txt 

awk -F '\t' 'NR==1 || ( $2 ~ /Pseudomonas aeruginosa/ && $5 ~ /pathogen/)' burkholderia_pseudomonas_pags.txt > pseudomonas_pags.txt

# install ncbi E-utilities to download fasta for PAGs
cd ~ | \ 
	sh -c "$(curl -fsSL ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"


# prepare a fasta file with all PAGs
# 56 PAGs were found after de-duplication of access numbers
/home/mdprieto/edirect/epost -db protein -input /home/mdprieto/git/hilliam_pseudomonas_2022/accession_pags.txt | \ 
	/home/mdprieto/edirect/efetch -format fasta > pags_fasta.fa

``` 

### BLAST PAG in newly assembled genomes

```sh
#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=12G #  GB of memory per cpu core
#SBATCH --time=00:20:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=1 # CPU cores per task
#SBATCH --job-name="blast_preparation"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --output=blast_preparation.out

###########################################################################

# load blast+ module

module purge
module load StdEnv/2020  gcc/9.3.0 blast+/2.12.0

# ---------------- create pathway variables

blast_db="/scratch/mdprieto/results_hilliam/blastdb"
contigs_dir="/scratch/mdprieto/results_hilliam/sample_contigs"

# ---------------- new directory with sample name appended to the contigs
# finds 'contigs.fa' filenames downstream
# appends 'sample_name' to each 'contigs.fa' in a new folder 'sample_contigs'

mkdir -p $contigs_dir
for i in `find /scratch/mdprieto/results_hilliam/shovill -name "contigs.fa"`
   do cp -n $i $contigs_dir/`echo $i| awk -F/ '{print $6 "_" $7}' `
done

# ---------------- add isolate ID to each contig
# finds sequence headers starting with > and adds the isolate ID before contig

cd $contigs_dir
for i in `ls $contigs_dir`
	do
	isolate=$(echo $i | grep -oE '[0-9]{1,3}-[ABC][0-9]*')
	echo $isolate
	perl -pi -e "s/^>/>$isolate\_/" $i 
	head -n 5 $i
	done
	

grep -oE '[0-9]{1,3}-[ABC][0-9]*'

# ---------------- make blast database for each genome
# create and move to working directory

mkdir -p $blast_db
cd $blast_db

# create individual databases for each sample_contig

for i in `ls $contigs_dir`
	do 
	assembly="$contigs_dir/$i"
	echo $assembly
	makeblastdb \
		-dbtype nucl \
		-in $assembly \
		-out $blast_db/$i.nt \
		-parse_seqids \
		-title "$i_blast_database"
	done

# ---------------- create unified database for all sample contigs

# lists all blast db in folder with output of path only

blastdbcmd -list $blast_db -list_outfmt '%f' > blast_databases.txt 

# now, given the text file with all databases, it creates a virtual database merging all	

blastdb_aliastool \
	-dblist_file $blast_db/blast_databases.txt \
	-dbtype nucl \
	-title "hilliam_pseudomonas_assemblies" \
	-out $blast_db/hilliam_assemblies
	
```

Script to run the tblastn, protein to nucleotide BLAST

```sh

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
	
tblastn -query /home/mdprieto/git/hilliam_pseudomonas_2022/pags_fasta.fa \
	-db /scratch/mdprieto/results_hilliam/blastdb/hilliam_assemblies \
	-show_gis \
	-outfmt 6 \
	-out /scratch/mdprieto/hilliam_blast_full.txt \
	-evalue 1e-50 \
	-num_threads 4 \
	-max_hsps 1
```



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
