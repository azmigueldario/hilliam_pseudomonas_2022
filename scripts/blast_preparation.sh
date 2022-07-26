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
