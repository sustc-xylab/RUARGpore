#!/usr/bin/env Rscript
system("echo \n")
#### read in system arguements ######
options(echo=F) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)

library(plyr)
library(data.table)
library(foreach)
library(doParallel)

# read in new SNP-free SARG ----
arg<-fread(args[1],header=F)
colnames(arg)<-c("query","subject","similarity","align.lenth","mismatch","gap","q.start","q.end","s.start","s.end","evalue","bitscore","s.len","q.len")

no_threads<-as.numeric(args[2])

load(args[3])
overlap.db<-l

taxa<-fread(args[4])
colnames(taxa)[1]<-c("query")

simcutoff=as.numeric(args[5])
lencutoff=as.numeric(args[6])

barcode=fread(args[9],header=F)
colnames(barcode)<-c("barcode","query","length")
barcode<-barcode[,1:2]

########################
# SARG filtering
########################
arg.filter<-function(arg.coliform,simcutoff=70,lencutoff=0.9){
	colnames(arg.coliform)<-c("query","subject","similarity","align.lenth","mismatch","gap","q.start","q.end","s.start","s.end","evalue","bitscore","s.len","q.len")
	# arg.coliform$query<-sapply(strsplit(arg.coliform$query,"-"),"[[",1)

	# filtering hit based on similarity & alignment length of the ARG length
	lookat<-which(arg.coliform$similarity>simcutoff & arg.coliform$align.lenth/arg.coliform$s.len>lencutoff)
	arg.coliform2<-arg.coliform[lookat,]

	if(nrow(arg.coliform2)>0){
	  #### remove the case where the same region on nanopore read hit to multiple ARGs ####
	  tmp.lst<-split(arg.coliform2,arg.coliform2$query)
	  
	  # for one region exactly hit to multiple ARG, only the best hit (the one with highest bitscore also the first hit ) was kept
	  tmp.lst<-lapply(tmp.lst, function(x) x[!duplicated(x$q.start),])
	  tmp.lst<-lapply(tmp.lst, function(x) x[!duplicated(x$q.end),])
	  # lapply(tmp.lst,nrow)
	  
	  # if one region hit to multiple ARG, then if the hited region is overlaped > 50% alignment length with the first hit (the hit with highest bitscore) then it will be removed, otherwise it will be kept.  ##
	  
	  for(g in 1:length(tmp.lst)) {
		x<-tmp.lst[[g]]
		# makesure q.start<q.end, flip q.end and q.start if not satisfy this standard
		lookat<-which(apply(x,1,function(y) as.numeric(y[7])> as.numeric(y[8])))
		tmp<-x[lookat,7]
		tmp2<-x[lookat,8]
		x[lookat,7]<-tmp2
		x[lookat,8]<-tmp
		# if nrow(x) > 2 then need to do clustering and then filter each cluster 
		if(nrow(x)>=2){
		  x<-x[order(x$bitscore,decreasing=T),] # line with highest bitscore as first line
		  tmp6<-list()
		  tmp5<-vector() # store the line overlaped more than 80% with the first line, these lines should be deleted
		  for(i in 1:(nrow(x)-1)){
			tmp5<-vector()
			for(j in (i+1):nrow(x)){
			  tmp.start<-max(x[i,]$q.start,x[j,]$q.start)
			  tmp.end<-min(x[i,]$q.end,x[j,]$q.end)
			  overlap<-tmp.end-tmp.start
			  # if no overlap with the first line， then overlap should be <=0, and this line should be kept for another loop
			  # overlap with first line for more than 50% of alignment length
			  if(overlap>x[j,]$align.lenth*0.5) {tmp5[j-1]<-j}
			}
			tmp6[[i]]<-tmp5
		  }
		  tmp6<-unique(unlist(tmp6))
		  tmp6<-tmp6[!is.na(tmp6)]
		  if(length(tmp6>0)){tmp.lst[[g]]<-x[-tmp6,]}
		  else {tmp.lst[[g]]<-x}
		}
	  }

	  
	  arg.colifom4<-rbind.fill(tmp.lst)
	  arg.colifom4$acc<-sapply(strsplit(as.character(arg.colifom4$subject),":"),"[[",1)

	  
	  # merge ARG annotation with ARDB type #
	  tmp<-merge(arg.colifom4,overlap.db,by="acc")
	  arg.colifom4<-tmp
	  
	}  else { 
	  cat("Warning!: NO ARG identified\nbelow items will be empty；\narg.tab\narg.w.taxa.tab\n")
	  arg.colifom4<-arg.coliform2
	}
	
	return(arg.colifom4)


}


arg.f<-arg.filter(arg,
				simcutoff=simcutoff,
				lencutoff=lencutoff
)
arg.f<-arg.f[,c("query","subtype","type","q.start","q.end")]

# merge in barcode
arg.f2<-merge(arg.f,barcode, by="query", all.x=T)

# get ARG profile of nanopore query with taxa classification
# summary results in arg.summary
if(nrow(arg.f)>0){
	arg.w.taxa<-merge(arg.f,taxa,by="query",all.x=T)
	
	arg.w.taxa[is.na(arg.w.taxa)]<-""
	arg.c<-aggregate( query~subtype+type,arg.w.taxa,length)
	# arg.c$copy.per.cell<-arg.c$query/NO.c
	colnames(arg.c)[3]<-c("No.reads")
	
	# --  write out ----
	write.table(arg.w.taxa,file=args[7], quote=F,row.names = F,sep="\t")
	# write.table(arg.c,file=args[8], quote=F,row.names = F,sep="\t")
	write.table(arg.f2,file=args[8], quote=F,row.names = F,sep="\t") # write out the arg annotation per read
	
} else { 
  cat("Warning: NO ARG identified\nOnly taxa annotations were generated \n")
  
}
