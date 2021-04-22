#!/bin/bash

########################################################################################
## import config variables
########################################################################################
source dect.config

########################################################################################
## do not manipulate
########################################################################################

if [ ! -z $1 ]; then
	if [[ "$1" == "-h" ]]; then
		for AIN in $AINS
		do
			LAST_LINE=$( tail -n 1 "$OUTPUT_30SEC$AIN.data" )
			printf "$LAST_LINE\n" >> "$OUTPUT_HOURLY$AIN.data"
		done
	elif [[ "$1" == "-d" ]]; then
		for AIN in $AINS
		do
			LAST_LINE=$( tail -n 1 "$OUTPUT_30SEC$AIN.data" )
			printf "$LAST_LINE\n" >> "$OUTPUT_DAILY$AIN.data"
		done
	elif [[ "$1" == "-m" ]]; then
		for AIN in $AINS
		do
			LAST_LINE=$( tail -n 1 "$OUTPUT_30SEC$AIN.data" )
			printf "$LAST_LINE\n" >> "$OUTPUT_MONTHLY$AIN.data"
		done
	fi
fi
