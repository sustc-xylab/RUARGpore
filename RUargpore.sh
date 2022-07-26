#!/bin/bash
## RUARGpore is designed to realize real-time identify ARGs and their host during nanopore selective sequencing
##Author: Yu XIA & Yuhong SUN 2022-07-26
##Email: shuixia100@gmail.com
##version 1.0

set -e 

n=1
SCRIPT=`realpath $0`
DIR=`dirname $SCRIPT`
nowt=`date +%Y-%m-%d.%H:%M:%S`;
out=out_RUARGpore_$nowt
threads=20

echo "Enter your sequencing time(h): "
read time
time=$[$time*60]

echo "Enter GridION IP and the $PATH_to_your_$fastq_pass directory :
e.g. grid@10.16.15.140:/data/usr/20220616_0415_X2_FAT17403_aacfbc92/fastq_pass"
read address


echo "Enter your GridION password:"
read password

echo "Enter No. of threads you intended to use for ARG identification (default 20):"
read threads


if [ ! -d $out ]; then
        mkdir $out;
else
        echo "Warning: $out already exists. previous results are overwrited"
                rm -rf $out
                mkdir -p $out
fi


echo "waiting for sequencing ..."
cd $out

while [ $time > 0 ]
do
	sleep 2m
        		
		echo "copying the $n 30min results from GridION to local server"
		ip=`echo $address | cut -f 1 -d :`
		dir=`echo $address | cut -f 2 -d :`
        
		if [ $n == 1 ]
		then
			
			sshpass -p $password ssh $ip find $dir -name "*.fastq.gz" > $n.all.list
			
			sshpass -p $password scp -r $address ./
			
			mv $n.all.list fastq_pass
			
		else
			mkdir -p fastq_pass
			cd fastq_pass
			
			sshpass -p $password ssh $ip find $dir -name "*.fastq.gz" > $n.all.list
			
			m=$[$n-1]
			# cp previous list
			cp ../fastq_pass_$m/$m.all.list . 
			
			#compare with previous list to determine which file to download
			diff $m.all.list $n.all.list | sed 's/>//' | grep "fastq" > $n.todownload.list
			
			# download required files
			cat $n.todownload.lst | while read line
			do
				sshpass -p $password scp ${ip}:${line} ./
			done
			
			# move downloaded fastq.gz to corresponding folder of barcode
			cat $n.todownload.lst | rev | cut -d "/" -f 1,2 | rev | sed 's/\//\t/g' > tmp_RUARGpore
			cat tmp_RUARGpore | while read line
			do	
				folder=`echo $line | cut -f 1 -d " "`
				file=`echo $line | cut -f 2 -d " "`
				
				if [ ! -d $folder ]
				then 
					mkdir $folder
					mv $file $folder
                else
					mv $file $folder
				fi
				
			done
			rm -f tmp_RUARGpore
			cd ..
		
		fi
		
		mv fastq_pass fastq_pass_$n
		
		echo "finish copying"
		
        cd fastq_pass_$n
				
		barcode=`ls . | grep "barcode" | wc -l`
				
		if [ $barcode == 0 ]
		then
			
			echo "no barcode was found"
			gz=`ls .| grep "fastq.gz" | wc -l`
			
			if [ $gz -gt 1 ]
			then
				# remove the newest generated fastq and combine into one fasta
				i=$(ls -l |grep "^-"|wc -l)
				i=$[$i-1]
				rm *_$i.fastq.gz
				cat *.fastq.gz > $n.fastq.gz
				${DIR}/bin/seqkit fq2fa $n.fastq.gz -o $n.fa
				$DIR/bin/fastaNameLengh.pl $n.fa > $n.fa.barcode
				sed -i "s/^/nobarcode\t/g" $n.fa.barcode
				rm -f $n.fastq.gz
			else
				echo "data ERROR: NO fastq.gz was found"
			fi
		
		else
		
			ls ./barcode* -d | sed 's/.\///' | while read line
			do
				i=$(ls -l $line|grep "^-"|wc -l)
				i=$[$i-1]
				rm ${line}/*_$i.fastq.gz
				cat $line/*.fastq.gz > $line.fastq.gz
				${DIR}/bin/seqkit fq2fa $line.fastq.gz -o $line.fa
				$DIR/bin/fastaNameLengh.pl $line.fa > $line.fa.barcode.tab
				sed -i "s/^/$line\t/g" $line.fa.barcode.tab
			done
			
			cat barcode*.fa > $n.fa
			cat barcode*.fa.barcode.tab > $n.fa.barcode
			rm barcode*.fa
			rm barcode*.fa.barcode.tab
			rm barcode*.fastq.gz
		
		fi
		
		echo "Start ARG identification for $n.fa"
        
		bash ${DIR}/argpore.sh -f $n.fa -t ${threads}  
		
		echo "Finish ARG identification for $n.fa"
				
        cd ../
		
		# combine each 30min results into accumulative results
		find . -name "*_taxa.tab" -exec cat '{}' > ${n}_argpore.taxa.tab \;
		find . -name "*_arg.w.taxa.tab" -exec cat '{}' > ${n}_argpore.arg.w.taxa.tab \;
		find . -name "*_arg.tab" -exec cat '{}' > ${n}_argpore.arg.tab \;
		
		
		# sendEmail -f m17806250691_1@163.com -t sunyuhong0124@126.com -s smtp.126.com  -u "测试"  -xp 01080124163yx -m "hello" -a ./test.fa -o message-charset=utf-8 #有问题
		# mail -s "ARG results for the first $n 30min" shuixia100@gmail.com <<< $n_argpore.arg.w.taxa.tab
		
        time=$[$time-$n*30]
		n=$[$n+1]
done
wait

echo "Finish RUARGpore!"
