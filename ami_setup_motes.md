# Amazon EC2 AMI setup notes

We start with the Ubuntu xenial 16.04 EBS-backed AMI for the us-east-1 region.

## Boot AMI

AMI was started as type **c4xlarge** with a 200GB EBS boot volume. This instance type has 16 CPU cores and ~30GB of memory.

## Set up data directory

```bash
sudo mkdir /data
sudo chown -R ubuntu /data
sudo chmod -R 775 /data
```

## Set up swap disk

```bash
sudo fallocate -l 10G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo cp /etc/fstab /etc/fstab.bak
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Install R 3.4 and Bioconductor 3.6

Add the line below to `/etc/apt/sources.list`

```
deb https://cloud.r-project.org/bin/linux/ubuntu xenial/
```

Execute the following to add the appropriate signing key:

```bash
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
```

Update packages and install R:

```bash
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install r-base r-base-dev
sudo apt-get install libcurl4-openssl-dev libxml2-dev #for specific R packages
sudo apt-get install htop samtools parallel bowtie procmail python-pip tmux texlive-full
```
Install R and Bioconductor packages by sourcing the following script from a root R session:

```S
update.packages(ask=F)
install.packages(c("reshape", "ggplot2", "stringr", "optparse", "dplyr", "knitr", "rmarkdown", "magrittr", "Rmisc", "RCurl", "pander", "seqLogo"))

source("http://bioconductor.org/biocLite.R")
biocLite()

bioc_packages <- c("GenomicRanges",
                   "rtracklayer",
                   "BSgenome.Dmelanogaster.UCSC.dm3",
                   "ShortRead",
                   "GenomicAlignments")

biocLite(bioc_packages)
````
Install dps BSgenome package

dps BSgenome package based on dp3 has been forged and downloaded to /data/bsgenome

Install the package with

```bash
R CMD INSTALL BSgenome.Dpseudoobscura.UCSC.dp3
```

Setup RStudio Server

```bash
mkdir /data/software
cd /data/software
sudo apt-get install gdebi-core
wget https://download2.rstudio.org/rstudio-server-1.1.453-amd64.deb $ sudo gdebi rstudio-server-1.1.453-amd64.deb
sudo gdebi rstudio-server-1.1.453-amd64.deb
```
**Please note the passwd for ubuntu was set as ubuntu**

## Download analysis code

```bash
cd /data
git clone https://github.com/zeitlingerlab/Shao_NG_2017 analysis_code
```

## Install cutadapt

```bash
cd /data/software
git clone https://github.com/marcelm/cutadapt.git
cd cutadapt

pip install Cython
sudo python setup.py install
```

## Getting genome fasta files

dm3 and dp3 genome are downloaded from UCSC Genome Browser, plasmid fasta files are generated manually.

```bash
mkdir -p /data/genomes/dm3
mkdir  /data/genomes/dp3

cd /data/genomes/dm3/
wget 'http://hgdownload.cse.ucsc.edu/goldenPath/dm3/bigZips/chromFa.tar.gz'
tar -xf chromFa.tar.gz
cat *.fa > dm3.fasta
rm *.fa
mv dm3.fasta /data/genomes

cd /data/genomes/dp3/
wget 'http://hgdownload.soe.ucsc.edu/goldenPath/dp3/bigZips/chromFa.zip'
unzip chromFa.zip
cat *.fa > dp3.fasta
rm *.fa
mv dp3.fasta /data/genomes
```

## Creating Bowtie index

```bash
bowtie-build dp3.fasta dp3

parallel -uj 4 ./create_plasmid_index.sh {} ::: uas_*.fasta
mkdir /data/bowtie_index
mv *.ebwt /data/bowtie_index/
```

## Preprocess ChIP-nexus and gene-specific RNA 5' sequencing FASTQ reads

ChIP-nexus samples start with 4 bp fixed barcode and 5 bp random barcode.
Gene-specific RNA 5' sequencing samples start with only 4 bp fixed barcode.

```bash
mkdir /data/preprocessed_fastq
cd /data/preprocessed_fastq

parallel -uj 2 Rscript /data/analysis_code/pipeline/preprocess_fastq.r -f {} -k 22 -b CTGA,TGAC,GACT,ACTG -t 50 -r 5 -p 5 -o \`basename {} .fastq.gz\`_processed.fastq.gz ::: /data/raw_fastq/*chipnexus*.fastq.gz

parallel -uj 5 Rscript /data/analysis_code/pipeline/preprocess_fastq.r -f {} -k 22 -b CTGA,TGAC,GACT,ACTG -t 50 -r 0 -p 2 -o \`basename {} .fastq.gz\`_processed.fastq.gz ::: /data/raw_fastq/*rna_5_sequencing*.fastq.gz
```


## Align ChIP-nexus and gene-specific RNA 5' sequencing samples

The following code is run in R

```S
library(parallel)
setwd("/data/preprocessed_fastq")
sample_info <- read.table("/data/sample_summary.txt", header =T, sep = "\t")

nothing <- mclapply(sample_info$sample_name, function(x){
    message("Processing ", x)
    genome <- subset(sample_info, sample_name == x)$genome
    system(paste0("/data/analysis_code/pipeline/align_chipnexus.sh ",x, "_processed.fastq.gz /data/bowtie_index/", genome))
}, mc.cores = 2)
```

resulting files are moved to /data/bam

```bash
mkdir /data/bam/
mv *.bam /data/bam
```


## Process aligned ChIP-nexus and gene-specific RNA 5' sequencing reads

```bash
mkdir /data/granges
cd /data/granges
parallel -uj 10 Rscript /data/analysis_code/pipeline/process_chipnexus_bam.r -f {} -n \`basename {} .bam\` ::: /data/bam/*chipnexus*.bam
parallel -uj 10 Rscript /data/analysis_code/pipeline/process_chipnexus_bam.r -f {} -n \`basename {} .bam\` -u F ::: /data/bam/*rna_5_sequencing*.bam
```


## Generate normalized  BigWigs files

```bash
mkdir /data/bigwig
cd /data/bigwig

parallel -uj 8 Rscript /data/analysis_code/pipeline/generating_bw_from_gr.r -f {}  -n \`basename {} .granges.rds\`_normalized -t chipnexus ::: /data/granges/*.rds
```
