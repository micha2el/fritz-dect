#!/bin/bash

########################################################################################
# set config variable and import config
########################################################################################
SOURCE=/usr/local/bin/dect/dect.config

########################################################################################
# DO NOT EDIT below here!
########################################################################################
if [[ ! -f $SOURCE ]]; then
 echo "Config file does not exist... stopping"
 exit
fi
source $SOURCE

DEBUG=0
if [ "$1" = "debug" ]; then
 DEBUG=1
 echo "Debug Output enabled"
fi

lastSID=$lastSID

# create sid file if not already exists
touch $lastSID

# read old SID
SID=$(cat $lastSID)

# check SID
LOGIN=$(curl $box/login_sid.lua?sid=$SID 2>/dev/null)
SID=$(echo -n "$LOGIN" | grep -oP "(?<=<SID>)[^<]*")

# read dynamic password salt
Challenge=$(echo -n "$LOGIN" | grep -oP "(?<=<Challenge>)[^<]*")

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
  SID=$(echo -n "$ACCESS" | grep -oP "(?<=<SID>)[^<]*")
#   BlockTime=`sed -n -e 's/.*<BlockTime>\(.*\)<\/BlockTime>.*/\1/p' <<<$ACCESS`
#   Rights=`sed -n -e 's/.*<Rights>\(.*\)<\/Rights>.*/\1/p' <<<$ACCESS`
fi

if [ "$SID" = "0000000000000000" ];then
	echo "Could not log into Fritz!Box. Check credentials?"
	exit
fi
# read AIN data
if [ "$DEBUG" = "1" ]
then
 printf "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<devices>\n"
 #DEVINFO=`curl "$box/webservices/homeautoswitch.lua?switchcmd=getdevicelistinfos&sid=$SID" 2>/dev/null`
 #echo $DEVINFO
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
 elif (( $TYPE & 2**(6) )); then
	DEVICE=2
 elif (( $TYPE & 2**(0) )); then
	DEVICE=3
 elif (( $TYPE & 2**(5) )); then
	DEVICE=4
 fi
 DATE=`date +%s`
 if [ "$DEVICE" = "1" ]; then
  # Outlet / Switch
  TEMP=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
  TEMP=`echo "scale=1; $TEMP / 10" | bc `
  STATE=`echo $DEVINFO | grep -oP "(?<=<switch><state>)[^<]*"`

  # read current 
  CURRENT=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getswitchpower&sid=$SID" 2>/dev/null `

  # read power consumption since last reset
  ENERGY=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getswitchenergy&sid=$SID" 2>/dev/null `

  # read device infos
  DETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getbasicdevicestats&sid=$SID" 2>/dev/null `

  if [ "$DEBUG" = "1" ]; then
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<strom>$CURRENT</strom>\n<verbrauch>$ENERGY</verbrauch>\n<state>$STATE</state>\n$DEVINFO\n</device>\n"
   printf "T=$TEMP,L=$CURRENT,V=$ENERGY,Z=$DATE,STATE=$STATE;\n"
  else
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<strom>$CURRENT</strom>\n<verbrauch>$ENERGY</verbrauch>\n<state>$STATE</state>\n$DETAILS\n</device>\n" >> $TMP_FILE
   printf "T=$TEMP,L=$CURRENT,V=$ENERGY,Z=$DATE,STATE=$STATE;\n" >> "$OUTPUT_30SEC$AIN.data"
  fi
 elif [ "$DEVICE" = "2" ]; then
  # HKR
  TEMP=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
  TEMP=`echo "scale=1; $TEMP / 10" | bc `
  TSOLL=`echo $DEVINFO | grep -oP "(?<=<tsoll>)[^<]*"`
  TSOLL=$(( (TSOLL-16)/2 + 8 ))
  WOPEN=`echo $DEVINFO | grep -oP "(?<=<windowopenactiv>)[^<]*"`
  WOPENTIME=`echo $DEVINFO | grep -oP "(?<=<windowopenactiveendtime>)[^<]*"`
  BATTERY=`echo $DEVINFO | grep -oP "(?<=name><battery>)[^<]*"`
  BOOST=`echo $DEVINFO | grep -oP "(?<=<boostactive>)[^<]*"`
  BOOSTTIME=`echo $DEVINFO | grep -oP "(?<=<boostactiveendtime>)[^<]*"`
  # read device infos
  DETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getbasicdevicestats&sid=$SID" 2>/dev/null `
  if [ "$DEBUG" = "1" ]; then
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<tsoll>$TSOLL</tsoll>\n<strom>0</strom>\n<wopen>$WOPEN</wopen>\n<wopentime>$WOPENTIME</wopentime>\n<battery>$BATTERY</battery>\n<boost>$BOOST</boost>\n<boosttime>$BOOSTTIME</boosttime>\n<verbrauch>0</verbrauch>\n$DEVINFO\n</device>\n"
   printf "T=$TEMP,L=0,V=0,Z=$DATE,TS=$TSOLL,WO=$WOPEN,B=$BATTERY,BOOST=$BOOST;\n"
  else
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<tsoll>$TSOLL</tsoll>\n<strom>0</strom>\n<verbrauch>0</verbrauch>\n<wopen>$WOPEN</wopen>\n<wopentime>$WOPENTIME</wopentime>\n<battery>$BATTERY</battery>\n<boost>$BOOST</boost>\n<boosttime>$BOOSTTIME</boosttime>\n$DETAILS\n</device>\n" >> $TMP_FILE
   printf "T=$TEMP,L=0,V=0,Z=$DATE,TS=$TSOLL,WO=$WOPEN,B=$BATTERY,BOOST=$BOOST;\n" >> "$OUTPUT_30SEC$AIN.data"
  fi
 elif [ "$DEVICE" = "3" ]; then
  # HAN FUN Device
  # read device infos
  DEVDETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN-$TYPE&switchcmd=getdeviceinfos&sid=$SID" 2>/dev/null`
  SUBTYPE=`echo $DEVDETAILS | grep -oP "(?<=functionbitmask\=\")[^\"]*"`
  SUBDEVICE=-1
  if (( $SUBTYPE & 2**(18) )); then
	SUBDEVICE=31
  fi
  if [ "$SUBDEVICE" = "31" ]; then
   LEVEL=`echo $DEVDETAILS | grep -oP "(?<=<levelpercentage>)[^<]*"`
   if [ "$DEBUG" = "1" ]; then
    printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$SUBDEVICE\">\n<level>$LEVEL</level>\n$DEVDETAILS\n</device>\n"
   else
    printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$SUBDEVICE\">\n<level>$LEVEL</level>\n$DEVDETAILS\n</device>\n" >> $TMP_FILE
   fi
  fi
 elif [ "$DEVICE" = "4" ]; then
  TEMP=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
  TEMP=`echo "scale=1; $TEMP / 10" | bc `
  BATTERY=`echo $DEVINFO | grep -oP "(?<=name><battery>)[^<]*"`
  DETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getbasicdevicestats&sid=$SID" 2>/dev/null `
  if [ "$DEBUG" = "1" ]; then
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<battery>$BATTERY</battery>\n$DEVINFO\n</device>\n"
   printf "T=$TEMP,B=$BATTERY,Z=$DATE;\n"
  else
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<battery>$BATTERY</battery>\n$DETAILS\n</device>\n" >> $TMP_FILE
   printf "T=$TEMP,B=$BATTERY,Z=$DATE;\n" >> "$OUTPUT_30SEC$AIN.data"
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

