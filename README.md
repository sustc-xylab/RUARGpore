# RUARGpore

**real-time ARGs identification** during adaptive nanopore sequencing

RUARGpore is a easy-to-use bioinformatics pipeline to enable real-time identification of antibiotic resistance genes (ARGs) and its host populations during adaptive nanopore sequencing. RUARGpore runs on the local server. It will grab data from Gridion at regular intervals (30min by default), and then perform ARGs identification by ARGpore. 


Please read below instructions carefully to avoid unnecessary errors.

## Installation 
### Pre-requisites for RUARGpore 
	
	python2.7	### sudo apt install python2.7
	GNU parallel	### sudo apt install parallel
	sshpass			### sudo apt install sshpass
	git lfs	        ### sudo apt install git-lfs
	R and library: plyr, data.table, doParallel, foreach 
	

### Setup RUARGpore
	
	git clone https://github.com/sustc-xylab/RUARGpore
	
	cd RUARGpore
	
	bash ./setup.sh	

The setup.sh will install **blast+, Centrifuge** and then download **SARG database, MetaPhlan2 Markergene database** for you.

Next, the users need to prepare database for Centrifuge** and below is the command line to follow

move to the database directory

	cd database/

download the NCBI taxonomy to taxonomy/ in the current directory 

	centrifuge-download -o taxonomy taxonomy

download all complete fungi+bacteria+viral reference genome to library/.

	centrifuge-download -o library -m -d “bacteria,fungi,viral" refseq > seqid2taxid.map

download human reference genome

	centrifuge-download -o library -d "vertebrate_mammalian" -a "Chromosome" -t 9606 -c 'reference genome' >> seqid2taxid.map

combine all downloaded sequences into a single file

	cat library/*/*.fna > input-sequences.fna

build centrifuge index with 4 threads

	centrifuge-build -p 4 --conversion-table seqid2taxid.map \
                 --taxonomy-tree taxonomy/nodes.dmp \
                 --name-table taxonomy/names.dmp \
                 input-sequences.fna h+b+f+v




NOTICE: This step will take at least **24 hour** to finish, please stay patient :)



## Using RUARGpore
The user need to start adaptive nanopore sequencing on GridION/MinION first, once you started nanopore selective sequencing, you could start RUARGpore using command below: 

	bash $PATH_to_RUARGpore/RUargpore.sh > RUargpore.log

Follow the prompts and input the information of:


	Enter your sequencing time(h): 
	48
	
	Enter GridION IP and the $PATH_to_your_$fastq_pass directory :
	grid@14.35.34.156:/data/usr/20220616_0415_X2_FAT17403_aacfbc92/fastq_pass
	
	Enter your GridION password: (e.g. admin)
	admin
	
	Enter No. of threads you intended to use for ARG identification:(e.g. 20). 
	20


**NOTICE:**
	you should add the ECDSA key fingerprint of your GridION to your known hosts of local server before run RUARGpore, you may simply acchieve this by ssh/scp to your GridION like below:
	
	scp -r grid@14.35.34.156:/data/usr/20220616_0415_X2_FAT17403_aacfbc92 ./
	
	The authenticity of host '14.35.34.156 (14.35.34.156)' can't be established.
	ECDSA key fingerprint is 12:4c:78:6e:f2:0e:0b:48:d8:bb:34:78:5b:66:22:2c.
	Are you sure you want to continue connecting (yes/no)? yes
	Warning: Permanently added '14.35.34.156' (ECDSA) to the list of known hosts.

	
#### Output files 
All output files of RUARGpore are stored in a folder named $out_RUARGpore_$NOWTIME in the working directory. In $out_RUARGpore_$NOWTIME directory the accumulative results for the first $n 30min analysis is stored in $n_ARGpore_output.tab 

Main output files include:
	
	$n_argpore.arg.tab		ARG identification per read 
	$n_argpore.taxa.tab		taxonomy assignment of all nanopore reads
	$n_argpore.arg.w.taxa.tab	ARGs-containing nanopore reads with taxonomy assignment
		
**e.g. 5_argpore.arg.tab stored ARGpore results of the first 2.5h (5×30min) adaptive sequencing run** 



## *Citation:*

If you use RUARGpore in your nanopore dataset analysis please cite:

Hang Cheng, Yuhong Sun, Qing Yang, Minggui Deng, Zhijian Yu, Lei Liu, Liang Yang*, 
Yu Xia*. 2022. An ultra-sensitive bacterial pathogen and antimicrobial resistance 
diagnosis workflow using Oxford Nanopore adaptive sampling sequencing method. 
MedRxiv

##### Tools included in ARGpore2 should be also cited, these tools includes: 

last, blast+, Centrifuge, MetaPhlan2, GNU parallel, R, python


