#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
	        logger "$DATE: OMG, Invalid API Log, Master!"
	else
		        exit 0
fi
