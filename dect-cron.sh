#!/bin/bash

########################################################################################
## config variables
########################################################################################

OUTPUT_30SEC=/var/www/dect/dect_30secs_ # OUTPUT file prefix for 30 seconds files
OUTPUT_HOURLY=/var/www/dect/dect_hourly_ # OUPUT file prefix for hourly files
OUTPUT_DAILY=/var/www/dect/dect_daily_ # OUPUT file prefix for daily files
OUTPUT_MONTHLY=/var/www/html/dect/dect_monthly_ # OUPUT file prefix for monthly files

########################################################################################
## actor identification number for DECT devices
########################################################################################
AINS="116300176784 116300172651 116300146166 116300250339"

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
