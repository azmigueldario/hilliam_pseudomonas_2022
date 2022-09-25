# Analysis of pathogen associated genes in Pseudomonas spp. 

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


### Tips to run assembly jobs on Cedar (CC)

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

######################## create new dir with assemblies #############################

contigs_dir="/scratch/mdprieto/results_hilliam/sample_contigs"

# new directory with sample name appended to the contigs
# finds 'contigs.fa' filenames downstream
# appends 'sample_name' to each 'contigs.fa' in a new folder 'sample_contigs'

mkdir -p $contigs_dir
for i in `find /scratch/mdprieto/results_hilliam/shovill -name "contigs.fa"`
   do cp -n $i $contigs_dir/`echo $i| awk -F/ '{print $6 "_" $7}' `
done

```

## QC of assembly

### Quast 

We will use QUAST to generate genome assembly metrics. Before running it, we need to download the reference genome for Pseudomonas aeruginosa (PA1). The output directory is specified with the option `-P`

```sh

# genomic fasta
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/496/605/GCF_000496605.2_ASM49660v2/GCF_000496605.2_ASM49660v2_genomic.fna.gz -P /project/6056895/mdprieto/hilliam_pseudomonas/pseudomonas_pa1_reference

# genomic coordinates annotation
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/496/605/GCF_000496605.2_ASM49660v2/GCF_000496605.2_ASM49660v2_genomic.gff.gz -P /project/6056895/mdprieto/hilliam_pseudomonas/pseudomonas_pa1_reference
```
Now, we run quast with and without reference genome. With reference genome we obtain basic assembly measures and metrics of coverage against the curated assembly. Without a reference, we would obtain only the basic measures. 

```sh
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

```

### CheckM

**CheckM** infers the quality of the genome assembly based on the presence and uniqueness of these sets of gene markers. It determines the completeness (coverage of reference genome) and the contamination of the input draft genomes.

**CheckM** is not available in the CC cluster. To install it, we create a virtual environment of python in our home directory. After loading the interpreter, we load the `scipy-stack` module that contains necessary python dependencies (matplotlib and numpy). Also, we load a set of bioinformatic tools dependencies (pplacer, prodigal and hmmer). 

```sh
module load python/3.10.2 scipy-stack
module load pplacer/1.1.alpha19 prodigal/2.6.3 hmmer/3.2.1
```
Is best practice to create virtual environment in your home or project directory. I create `checkm_genome_env` in the home dir; python dependencies are installed after loading environment. The `--no-index` option for python libraries installs those optimized for the compute canada cluster. 

__CheckM__ requires precalculated data files, which we download to a directory recognized by the tool. 

```sh
cd ~
virtualenv --no-download checkm_genome_env

source ~/checkm_genome_env/bin/activate
pip install --no-index pysam
pip install --no-index checkm_genome

# unpack precalculated data files
mkdir -p /home/mdprieto/checkm_genome_env/data 
cd /home/mdprieto/checkm_genome_env/data
wget https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz
tar -xzf checkm_data_2015_01_16.tar.gz

# tell program where data was unpacked
export CHECKM_DATA_PATH=/home/mdprieto/checkm_genome_env/data
checkm data setRoot /home/mdprieto/checkm_genome_env/data
```

Run job

```sh

#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=8G #  GB of memory per cpu core
#SBATCH --time=04:00:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=12 # CPU cores per task
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

# select marker set for P. aeruginosa
checkm taxon_set species 'Pseudomonas aeruginosa' $output_dir/pseudomonas.ms
date

##################################   analyze  #################################

# analyze completeness and contamination of 190 assemblies
checkm analyze \
        $output_dir/pseudomonas.ms `#file with checkm marker set for assemblies` \
        $contigs_dir `#dir with assemblies in fasta format` \
        $output_dir `#output directory` \
        -x fa `#extension of assemblies` \
        -t 12 `#number of threads for parallel processing`
date

# produce summary
checkm qa \
        $output_dir/pseudomonas.ms `#file with checkm marker set for assemblies` \
        $output_dir `#output directory` \
        --file $output_dir/checkm_output.tsv \
        --tab_table \
        --threads 12
date

```


## BLAST of pathogen associated genes

The pathogen associated genes are stored in a file in the git repo (`burkholderia_pseudomonas_pags.tx`). 

We use `awk` to extract only the pathogen associated genes (PAGs) of *Pseudomonas* spp. 

In the code, `NR==1` signals awk to extract the first line with the headers, `$2 ~ /Pseudomonas aeruginosa/ && $5 ~ /pathogen/` matches string to columns, and `-F '\t'` specifies that the file is tab delimited. We then use cut, tail and sort to extract the accession numbers, eliminate headers and keep only unique identifiers respectively. 

```sh
# change to the git folder with all primary input
cd /home/mdprieto/git/hilliam_pseudomonas_2022/

awk -F '\t' 'NR==1 || ( $2 ~ /Pseudomonas/ && $5 ~ /pathogen/)' burkholderia_pseudomonas_pags.txt | \
	cut -f 3 | \
	tail -n +2 | \
	sort -u > accession_pags.txt

``` 

We also use the NCBI e-utilities in order to get the aminoacid sequences for each of the PAGs proteins in fasta format. A collaborator provided two additional fasta files with sequences of proteins of interest, so we add them to our main file before running BLAST.

```sh
# install ncbi E-utilities in home dir
cd ~ | sh -c "$(curl -fsSL ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"

# save unique PAGs in a new txt file
/home/mdprieto/edirect/epost \
	-db protein \
	-format acc \
	-input /home/mdprieto/git/hilliam_pseudomonas_2022/accession_pags.txt | \
	/home/mdprieto/edirect/efetch \
	-format fasta > /home/mdprieto/git/hilliam_pseudomonas_2022/pags.fasta &

```

### BLAST PAG in newly assembled genomes

In order to run BLAST+ against our assembly files, we need to transform each assembly into a database that can be searched by BLAST. Thus, we create a list of all the contigs files from the resulting assemblies and create a BLAST database for each. Finally, we merge all these databases into a single one using `blastdb_aliastool` 

```sh

#!/bin/bash
#SBATCH --account=def-whsiao-ab
#SBATCH --mem-per-cpu=10G #  GB of memory per cpu core
#SBATCH --time=00:30:00
#SBATCH --ntasks=1 # tasks in parallel
#SBATCH --cpus-per-task=1 # CPU cores per task
#SBATCH --job-name="blast_preparation"
#SBATCH --chdir=/scratch/mdprieto/
#SBATCH --output=blast_preparation.out

###########################################################################
################################ preparation

# load blast+ module
module purge
module load StdEnv/2020  gcc/9.3.0 blast+/2.12.0

# create pathway variables
blast_db="/scratch/mdprieto/results_hilliam/blastdb"
contigs_dir="/scratch/mdprieto/results_hilliam/sample_contigs"


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

In the following script we will run BLAST+ to align the known PAGs to the genome assemblies from an external dataset (Hilliam-2017). Using the merged database created in the previous step, we run tblastn (protein to nucleotide)
using as query (to search) sequences a fasta file containing the protein sequence for all PAGs. 

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
	
tblastn -query /home/mdprieto/git/hilliam_pseudomonas_2022/pags.fasta \
	-db /scratch/mdprieto/results_hilliam/blastdb/hilliam_assemblies \
	-show_gis \
	-outfmt "7" \
	-out /scratch/mdprieto/hilliam_blast_full.txt \
	-evalue 1e-50 \
	-num_threads 4 \
	-max_hsps 1

# blast of additional proteins by collaborator (Patrick)
blastn \
	-query /home/mdprieto/git/hilliam_pseudomonas_2022/patrick_pags.fasta \
	-db /scratch/mdprieto/results_hilliam/blastdb/hilliam_assemblies \
	-show_gis \
	-outfmt "7" \
	-out /scratch/mdprieto/patrick_blast.txt \
	-evalue 1e-50 \
	-num_threads 4 \
	-max_hsps 1 
```
Finally, we move the results to our git repo directory and produce clean versions with headers.

```sh
# copy to git repo for project
cd ~/scratch
cp patrick_blast.txt hilliam_blast_full.txt ~/git/hilliam_pseudomonas_2022/results/

# clean format and add headers
cd ~/git/hilliam_pseudomonas_2022/results/
grep --invert-match "^#" hilliam_blast_full.txt | \
	sed '1s/^/qseqid\tsseqid\tpiden\tlength\tmismatch\tgapopen\tqstart\tqend\tsstart\tsend\tevalue\tbitscore\n/' \
	> hilliam_blast_clean.txt

grep --invert-match "^#" patrick_blast.txt | \
	sed '1s/^/qseqid\tsseqid\tpiden\tlength\tmismatch\tgapopen\tqstart\tqend\tsstart\tsend\tevalue\tbitscore\n/' \
	> patrick_blast_clean.txt	

```

### Analysis of functional groups in BLAST hits

To select optimal candidates for in-vitro evaluation in Aim2, we look for PAGs with transcriptional regulator activity among our hits. 

In our local machine, I set up the capacity to run multiple searches in `InterProScan` database. Requires installation of Java and running the `Install certificates.command` for our python version.

Using `vim`, I pasted the IDs of the PAGs that were found in all the cohort (96 patients) and saved it in `list_pags_all_samples.txt`. Then, using the `seqtk` utility, I create a new fasta file including only these interesting proteins. 

```sh
# work inside an environment and install dependencies
conda create -name interpro
conda activate interpro
pip3 install xmltramp2 requests

# install EMBI REST handler and interproscan script
git clone https://github.com/ebi-wp/webservice-clients.git
wget https://raw.githubusercontent.com/ebi-wp/webservice-clients/master/python/iprscan5.py

# one liner to extract 30 sequences in a file (limit for InterPro)
awk "/^>/ {n++} n>30 {exit} {print}" input_fasta > output_fasta

# new fasta with only PAGs found in all patients
seqtk subseq pags.fasta list_pags_all_samples.txt > pags_all_samples.fa

# run search
# options to output tsv, name output file, and reduce verbosity
python3 iprscan5.py \
	--sequence hilliam_pseudomonas_2022/pags_all_samples.fa \
	--email azmigueldario@gmail.com \
	--outformat tsv \
	--outfile results_interpro.tsv \
	--quiet &
  
# close environment once finished
conda deactivate interpro
```