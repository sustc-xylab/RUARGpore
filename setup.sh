#!/bin/bash
set -e

SCRIPT=`realpath $0`
DIR=`dirname $SCRIPT`

cd ${DIR}/bin

########## seqkit
echo "Installing seqkit ---------------------------------------------------------------------
"
wget https://github.com/shenwei356/seqkit/releases/download/v0.12.1/seqkit_linux_amd64.tar.gz --output-document 'seqkit_linux_amd64.tar.gz'
tar -zxvf seqkit_linux_amd64.tar.gz
rm seqkit_linux_amd64.tar.gz

############ blast+ 2.9.0
echo ""
echo "Installing blast+2.9.0 ---------------------------------------------------------------------
"
curl https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.11.0/ncbi-blast-2.11.0+-x64-linux.tar.gz --output ncbi-blast-2.11.0+-x64-linux.tar.gz
tar -zvxf ncbi-blast-2.11.0+-x64-linux.tar.gz
rm -f ncbi-blast-2.11.0+-x64-linux.tar.gz
rm -rf ncbi-blast+
mv ncbi-blast-2.11.0+ ncbi-blast+

########## Centrifuge
echo ""
echo "Intalling Centrifuge -------------------------------------------------------------------
"
wget ftp://ftp.ccb.jhu.edu/pub/infphilo/centrifuge/downloads/centrifuge-1.0.3-beta-Linux_x86_64.zip --output-document 'centrifuge-1.0.3-beta-Linux_x86_64.zip'
unzip centrifuge-1.0.3-beta-Linux_x86_64.zip
rm centrifuge-1.0.3-beta-Linux_x86_64.zip
rm -rf centrifuge
mv centrifuge-1.0.3-beta centrifuge


# echo "Finish install required tools 
# ------------------------------------------------------------------"


cd ${DIR}/database


# MetaPhlan2.0 markergene database ##############################
echo "
Downloading Metaphlan2 markergene database from git lfs"

git lfs install
git lfs pull

tar jxvf markers.fasta.tar.xz
echo "
Building lastdb for Metaphlan2 markergene database"
${DIR}/bin/last-983/src/lastdb -Q 0 markers.lastindex markers.fasta -P 10
$DIR/bin/fastaNameLengh.pl markers.fasta > markers.fasta.length
rm -f markers.fasta.tar.xz

###### SARG-nt database ################
echo "
Building lastdb for SARG-nt database"
tar jxvf SARG_20170328_5020.ffn.tar.xz
${DIR}/bin/last-983/src/lastdb -Q 0 SARG_20170328_5020.ffn SARG_20170328_5020.ffn -P 10

${DIR}/bin/fastaNameLengh.pl SARG_20170328_5020.ffn > SARG_20170328_5020.ffn.length
rm -f SARG_20170328_5020.ffn.tar.xz


########### lineage database ###################################################################
echo "
Downloading lineage information for NCBI taxonomy"

tar jxvf 2020-06-16_lineage.tab.tar.xz
mv database/2020-06-16_lineage.tab . 
rm -rf database


######### centrifuge database #################################
# echo "
# Downloading Centrifuge database"

# # wget https://genome-idx.s3.amazonaws.com/centrifuge/p_compressed%2Bh%2Bv.tar.gz --output-document 'p+b+v.tar.gz'
# # tar -zvxf p+b+v.tar.gz
# # rm p+b+v.tar.gz

# #download the NCBI taxonomy to taxonomy/ in the current directory 
# ${DIR}/bin/centrifuge/centrifuge-download -o taxonomy taxonomy

# # download all complete fungi+bacteria+viral reference genome to library/.
# ${DIR}/bin/centrifuge/centrifuge-download -o library -m -d "bacteria,fungi,viral" refseq > seqid2taxid.map

# #download human reference genome
# ${DIR}/bin/centrifuge/centrifuge-download -o library -d "vertebrate_mammalian" -a "Chromosome" -t 9606 -c 'reference genome' refseq >> seqid2taxid.map

# #concatenate all downloaded sequences into a single file
# cat library/*/*.fna > input-sequences.fna

# #build centrifuge index with 4 threads

# ${DIR}/bin/centrifuge/centrifuge-build -p 4 --conversion-table seqid2taxid.map \
                 # --taxonomy-tree taxonomy/nodes.dmp \
                 # --name-table taxonomy/names.dmp \
                 # input-sequences.fna hbfv

echo "Finish Download required databases
NOTICE: due to the long time required for downloading, centrifuge database needs to be parepared manually by users, please refer to ReadMe for detailed steps to prepare centrifuge database
------------------------------------------------------------------"
echo "Done ARGpore_pathogen setup"
