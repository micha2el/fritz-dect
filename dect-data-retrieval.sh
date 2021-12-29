#!/bin/bash

########################################################################################
# import config variables
########################################################################################
source /usr/local/bin/dect/dect.config

########################################################################################
# DEBUG mode ?
########################################################################################
DEBUG=0
if [ "$1" = "debug" ]; then
 DEBUG=1
 echo "Debug Output enabled"
fi

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
  if [ "$DEBUG" = "1" ]
  then
    ACCESS=$(curl -s "$box/login_sid.lua" -d "response=$response" -d 'username='${username})
  else
    ACCESS=$(curl -s "$box/login_sid.lua" -d "response=$response" -d 'username='${username} 2>/dev/null)
  fi

  SID=$(sed -n -e 's/.*<SID>\(.*\)<\/SID>.*/\1/p' <<<$ACCESS)
#   BlockTime=`sed -n -e 's/.*<BlockTime>\(.*\)<\/BlockTime>.*/\1/p' <<<$ACCESS`
#   Rights=`sed -n -e 's/.*<Rights>\(.*\)<\/Rights>.*/\1/p' <<<$ACCESS`
fi

# read AIN data
if [ "$DEBUG" = "1" ]
then
 printf "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<devices>\n"
else
 printf "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<devices>\n" > $TMP_FILE
fi
COUNTER=0
for AIN in $AINS
do
 NAME=${NAMES[$COUNTER]}
 # read device info 
 DEVINFO=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getdeviceinfos&sid=$SID" 2>/dev/null`
 TYPE=`echo $DEVINFO | grep -oP "(?<=functionbitmask\=\")[^\"]*"`
 DEVICE=-1
 if (( $TYPE & 2**(9) )); then
	DEVICE=1
 elif  (( $TYPE & 2**(6) )); then
	DEVICE=2
 fi
 DATE=`date +%s`
 if [ "$DEVICE" = "1" ]; then
  TEMP=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
  TEMP=`echo "scale=1; $TEMP / 10" | bc `

  # read current 
  CURRENT=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getswitchpower&sid=$SID" 2>/dev/null `

  # read power consumption since last reset
  ENERGY=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getswitchenergy&sid=$SID" 2>/dev/null `

  # read device infos
  DETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getbasicdevicestats&sid=$SID" 2>/dev/null `

  if [ "$DEBUG" = "1" ]; then
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<strom>$CURRENT</strom>\n<verbrauch>$ENERGY</verbrauch>\n</device>\n"
   printf "T=$TEMP,L=$CURRENT,V=$ENERGY,Z=$DATE;\n"
  else
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<strom>$CURRENT</strom>\n<verbrauch>$ENERGY</verbrauch>\n$DETAILS\n</device>\n" >> $TMP_FILE
   printf "T=$TEMP,L=$CURRENT,V=$ENERGY,Z=$DATE;\n" >> "$OUTPUT_30SEC$AIN.data"
  fi
 elif [ "$DEVICE" = "2" ]; then
  TEMP=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
  TEMP=`echo "scale=1; $TEMP / 10" | bc `
  TSOLL=`echo $DEVINFO | grep -oP "(?<=<tsoll>)[^<]*"`
  TSOLL=$(( (TSOLL-16)/2 + 8 ))
  # read device infos
  DETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getbasicdevicestats&sid=$SID" 2>/dev/null `
  if [ "$DEBUG" = "1" ]; then
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<tsoll>$TSOLL</tsoll>\n<strom>0</strom>\n<verbrauch>0</verbrauch>\n$DEVINFO\n</device>\n"
   printf "T=$TEMP,L=0,V=0,Z=$DATE,TS=$TSOLL;\n"
  else
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<tsoll>$TSOLL</tsoll>\n<strom>0</strom>\n<verbrauch>0</verbrauch>\n$DETAILS\n</device>\n" >> $TMP_FILE
   printf "T=$TEMP,L=0,V=0,Z=$DATE,TS=$TSOLL;\n" >> "$OUTPUT_30SEC$AIN.data"
  fi
 fi
 COUNTER=$((COUNTER+1))
done
if [ "$DEBUG" = "1" ]; then
 printf "</devices>\n"
else
 printf "</devices>\n" >> $TMP_FILE
 mv $TMP_FILE $OUTPUT_WEB
fi

