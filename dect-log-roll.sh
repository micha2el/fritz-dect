#!/bin/bash

########################################################################################
## import config variables
########################################################################################
source /usr/local/bin/dect/dect.config

########################################################################################
## do not manipulate
########################################################################################
DAILY_LIMIT=80640

if [ ! -z $1 ]; then
	if [[ "$1" == "-d" ]]; then
		for AIN in $AINS
		do
			FILE="$OUTPUT_30SEC$AIN.data"
			if [[ -f "$FILE" ]]; then
				tail -n $DAILY_LIMIT "$FILE" > "$OUTPUT_30SEC$AIN.new"
				mv "$OUTPUT_30SEC$AIN.new" $FILE
			fi
		done
	#elif [[ "$1" == "-d" ]]; then
	#	for AIN in $AINS
	#	do
	#		LAST_LINE=$( tail -n 1 "$OUTPUT_30SEC$AIN.data" )
	#		printf "$LAST_LINE\n" >> "$OUTPUT_DAILY$AIN.data"
	#	done
	#elif [[ "$1" == "-m" ]]; then
	#	for AIN in $AINS
	#	do
	#		LAST_LINE=$( tail -n 1 "$OUTPUT_30SEC$AIN.data" )
	#		printf "$LAST_LINE\n" >> "$OUTPUT_MONTHLY$AIN.data"
	#	done
	fi
fi
