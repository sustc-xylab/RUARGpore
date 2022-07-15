#!/bin/bash
## ARGpore is designed to identify ARGs and their host in nanopore dataset
##Author: Yu XIA 2020-06-11
##Email: shuixia100@gmail.com
##version 2.1
set -e

#### usage info ####
show_help() {
cat << EOF
version 2.1
arguments:
	-h	display this help 

	-f 	1D.fasta generated by nanopore sequncing as input for argpore

	-s	similarity cutoff [0-1] for filtering ARG lastal results
		default similarity cutoff is 0.7

	-l	alignment length cutoff [0-1] for filtering ARG lastal results
		default alignment length cutoff is 0.9

	-t	number of threads used for parallel computiong, default t=1


output files:
	input_arg.tab	ARG quntification (copy per cell)
	input_arg.w.taxa.tab	ARGs-containing nanopore reads with taxonomy assignment and plausible plasmid identification
	input_circular.tab	circular nanopore reads  identified
	input_plasmid.like.tab	plasmid-like nanopore reads identified 
	input_taxa.tab	taxonomy assignment of all nanopore reads


Example usage: 
	bash ../argpore.sh -f test.fa -t 20
EOF
}

####################
# define arguments
####################
OPTIND=1  # Reset in case getopts has been used previously in the shell.

# initial value of variables
N_threads="1"
Input_fa=""
Lencutoff="0.9"
Simcutoff="70"
nowt=`date +%Y-%m-%d.%H:%M:%S`;
SCRIPT=`realpath $0`
DIR=`dirname $SCRIPT`

while getopts "t:f:l:s:o:h" opt; do
	case "$opt" in
		h)
			show_help
			exit 0
			;;
		t)
			N_threads=$OPTARG
			;;
		f)
			Input_fa=$OPTARG
			;;
		l)
			Lencutoff=$OPTARG
			;;
		s)
			Simcutoff=`echo "$OPTARG*100"|bc`
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 0
			;;
		'?')
			show_help >&2
			exit 1
			;;
		-?*)
			print 'Warning: Unknown option (ignored) : %s\n' "$1" >&2
			exit 0
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
		*) # default case: if no more options then break out of the loop
			break
			
	esac
done

if [ -z "$Input_fa" ]
then
	echo "No input fasta, -f must be specified"
	exit
fi

shift "$((OPTIND-1))"
# echo $Input_fa $Simcutoff $Lencutoff $N_threads $Output $DIR $nowt

# subset the name of the $Input_fa
# $Input_fa : including input.fa path while $Input_fa2 only contain name
myarray=(`echo $Input_fa| tr "/" " "`) 
Input_fa2=${myarray[-1]}

echo "remove nanopore reads with duplicated name"
$DIR/bin/seqkit rmdup -n $Input_fa2 -o ${Input_fa2}.uniq

Input_fa2=${Input_fa2}.uniq
$DIR/bin/fastaNameLengh.pl ${Input_fa2} | grep -v "#" > ${Input_fa2}.l

echo "----------------------------------------------------------------------
start ARGpore @ `date +"%Y-%m-%d %T"`
"

echo "ARGpore_pathogen is runing using parameters:
Input fasta: $Input_fa2
Similarity cutoff for ARG identification: $Simcutoff
Alignment length cutoff for ARG identification: $Lencutoff
Number of threads: $N_threads
---------------------------------------------------------------------
"

#####################################################################
####### LAST against the SARG-nt and ESCG database
#####################################################################
echo "
----------------------------------------------------------------------------
Start ARG quantification @ `date +"%Y-%m-%d %T"`"

Query="${Input_fa2}"
bash $DIR/bin/sarg.sh $Query $N_threads $DIR $Simcutoff $Lencutoff

echo "
Finish ARG quantification @ `date +"%Y-%m-%d %T"`"


###############################################################
####### taxonomy annotation of combined.fa by centrifuge and MetaPhlan 2 markergene
###############################################################
echo "
----------------------------------------------------------------------------
Start taxonomy annotatin @ `date +"%Y-%m-%d %T"`"

Query="${Input_fa2}"
bash $DIR/bin/centrifuge_marker_chenghang.sh $Query $N_threads $DIR $Simcutoff $Lencutoff $nowt


echo "
Finish taxonomy annotation @ `date +"%Y-%m-%d %T"`"


# #########################################################
# ###### putative plasmid identification 
# #########################################################
# echo "-----------------------------------------------------------------------
# Start Plasmid identification @ `date +"%Y-%m-%d %T"`
# "
# Query="${Input_fa2}.orfs.faa"
# bash ${DIR}/bin/plasmid.identification.sh ${Input_fa2} ${DIR} $N_threads $Query $nowt
# echo "
# Finish Plasmid identification @ `date +"%Y-%m-%d %T"`"

# # #########################################################
# # #######identify circular contigs 
# # #########################################################
# # echo "
# # Finding circular contig " 
# # $DIR/bin/julia-1.4.2/bin/julia $DIR/bin/ccontigs/ccontigs.jl -i ${Input_fa2} -o ${Input_fa2}_circular.tab

# ########################################################## 
# ########## summary in nanopore.summary.R
# ##########################################################

echo "Summarizing results in R @ `date +"%Y-%m-%d %T"`"
Query=$Input_fa2
out1=${Query}_sarg

Rscript ${DIR}/bin/argpore_pathogen.R \
 ${out1}/${Query}_sarg.last \
 $N_threads \
 $DIR/database/structure.RData \
 ${Query}_taxa.tab \
 $Simcutoff \
 $Lencutoff \
 ${Query}_arg.w.taxa.tab \
 ${Query}_arg.tab


echo "
-----------------------------------------------------------------
Saving ARGpore_pathogen results 
"
out=`echo "${Input_fa2}_ARGpore_pathogen_${nowt}"`
echo "moving results to $out"
if [ ! -d $out ]; then 
	mkdir $out;
	mkdir $out/intermediate.files
else 
	rm -rf $out
	mkdir -f $out
	mkdir $out/intermediate.files

fi

mv ${Input_fa2} ${out}
mv ${Input_fa2}_sarg ${out}/intermediate.files
mv ${Input_fa2}_marker ${out}/intermediate.files
mv ${Input_fa2}_Centrifuge ${out}/intermediate.files
mv ${Input_fa2}_arg.w.taxa.tab ${out}
mv ${Input_fa2}_taxa.tab ${out}
mv ${Input_fa2}_arg.tab ${out}


echo "
done ARGpore_pathogen @ `date +"%Y-%m-%d %T"`
--------------------------------------------------------------------
"
