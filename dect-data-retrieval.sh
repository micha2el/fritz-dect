#!/bin/bash

########################################################################################
# import config variables
########################################################################################
source dect.config

########################################################################################
# do not manipulate 
########################################################################################
lastSID=$lastSID

# create sid file if not already exists
touch $lastSID

# read old SID
SID=$(cat $lastSID)

# check SID
LOGIN=$(curl $box/login_sid.lua?sid=$SID 2>/dev/null)
SID=$(sed -n -e 's/.*<SID>\(.*\)<\/SID>.*/\1/p' <<<$LOGIN )

# read dynamic password aslt
Challenge=$(sed -n -e 's/.*<Challenge>\(.*\)<\/Challenge>.*/\1/p' <<<$LOGIN)

# blocktime and rights are not used as of now
# BlockTime=`sed -n -e 's/.*<BlockTime>\(.*\)<\/BlockTime>.*/\1/p' <<<$LOGIN`
# Rights=`sed -n -e 's/.*<Rights>\(.*\)<\/Rights>.*/\1/p' <<<$LOGIN`

# check if login is necessary
if [ "$SID" = "0000000000000000" ]
then
  PWSTRING="$Challenge-$passwort"
  PWHASH=$(echo -n "$PWSTRING" |sed -e 's,.,&\n,g' | tr '\n' '\0' | md5sum | grep -o "[0-9a-z]\{32\}")
  response="$Challenge-$PWHASH"
  ACCESS=$(curl -s "$box/login_sid.lua" -d "response=$response" -d 'username='${username} 2>/dev/null)

  SID=$(sed -n -e 's/.*<SID>\(.*\)<\/SID>.*/\1/p' <<<$ACCESS)
#   BlockTime=`sed -n -e 's/.*<BlockTime>\(.*\)<\/BlockTime>.*/\1/p' <<<$ACCESS`
#   Rights=`sed -n -e 's/.*<Rights>\(.*\)<\/Rights>.*/\1/p' <<<$ACCESS`
fi

# read AIN data
printf "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<devices>\n" > $TMP_FILE
COUNTER=0
for AIN in $AINS
do
 NAME=${NAMES[$COUNTER]}
 # read temperatur and add ','
 TEMP=`   curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
 TEMP=`   echo "scale=1; $TEMP / 10" | bc `

 # read current 
 CURRENT=`  curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getswitchpower&sid=$SID" 2>/dev/null `

 # read power consumption since last reset
 ENERGY=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getswitchenergy&sid=$SID" 2>/dev/null `

 # read device infos
 DETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getbasicdevicestats&sid=$SID" 2>/dev/null `

 DATE=`date +%s`
 printf "<device ain=\"$AIN\" name=\"$NAME\">\n<temp>$TEMP</temp>\n<strom>$CURRENT</strom>\n<verbrauch>$ENERGY</verbrauch>\n$DETAILS\n</device>\n" >> $TMP_FILE
 printf "T=$TEMP,L=$CURRENT,V=$ENERGY,Z=$DATE;\n" >> "$OUTPUT_30SEC$AIN.data"
 COUNTER=$((COUNTER+1))

done
printf "</devices>\n" >> $TMP_FILE
mv $TMP_FILE $OUTPUT_WEB

