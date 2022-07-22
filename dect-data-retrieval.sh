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

TMP_FILE=$TMP_FILE"_"$RANDOM

########################################################################################
# functions to replace grep if necessary
########################################################################################
grep_data() {
 echo -n "$1" | grep -o "<$2>.*<\/$2>" | cut -f2 -d"<" | cut -f2 -d">"
}
grep_digit_property() {
 echo -n "$1" | grep -o "$2=\"[0-9 ]*\"" | cut -f2 -d"\""
}
########################################################################################

lastSID=$lastSID

# create sid file if not already exists
touch $lastSID

# read old SID
SID=$(cat $lastSID)

# check SID
LOGIN=$(curl $box/login_sid.lua?sid=$SID 2>/dev/null)
SID=$(grep_data "$LOGIN" "SID")

# read dynamic password salt
Challenge=$(grep_data "$LOGIN" "Challenge")

# blocktime and rights are not used as of now
# BlockTime=`sed -n -e 's/.*<BlockTime>\(.*\)<\/BlockTime>.*/\1/p' <<<$LOGIN`
# Rights=`sed -n -e 's/.*<Rights>\(.*\)<\/Rights>.*/\1/p' <<<$LOGIN`

# check if login is necessary
if [ "$SID" = "0000000000000000" ]
then
  if [ "$DEBUG" = "1" ]; then
	  echo "SID empty, logging in..."
  fi
  PWSTRING="$Challenge-$passwort"
  PWHASH=$(echo -n "$PWSTRING" |sed -e 's,.,&\n,g' | tr '\n' '\0' | md5sum | grep -o "[0-9a-z]\{32\}")
  response="$Challenge-$PWHASH"
  if [ "$DEBUG" = "1" ]
  then
    ACCESS=$(curl -s "$box/login_sid.lua" -d "response=$response" -d 'username='${username})
  else
    ACCESS=$(curl -s "$box/login_sid.lua" -d "response=$response" -d 'username='${username} 2>/dev/null)
  fi
  SID=$(grep_data "$ACCESS" "SID")
#   BlockTime=`sed -n -e 's/.*<BlockTime>\(.*\)<\/BlockTime>.*/\1/p' <<<$ACCESS`
#   Rights=`sed -n -e 's/.*<Rights>\(.*\)<\/Rights>.*/\1/p' <<<$ACCESS`
fi

if [ "$SID" = "0000000000000000" ];then
	echo "Could not log into Fritz!Box. Check credentials?"
	exit
fi
if [ "$DEBUG" = "1" ]; then
	echo "... logged in!"
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
ALLDEVS=`curl "$box/webservices/homeautoswitch.lua?switchcmd=getdevicelistinfos&sid=$SID" 2>/dev/null`
ALLDEVS=${ALLDEVS// /_\#}
ALLDEVS=${ALLDEVS//device_#identifier/ devide_\#identifier}
if [ "$DEBUG" = "1" ]; then
	echo $ALLDEVS
fi
ALLDEVS=($(echo $ALLDEVS | tr " " "\n"))

for AIN in $AINS
do
 NAME=${NAMES[$COUNTER]}
 # read device info 
 DEVINFO=""
 for i in "${ALLDEVS[@]}"
 do
	DEV=${i//_\#/ }
	DEVID=$(grep_digit_property "$DEV" "identifier")
	DEVID=${DEVID// /}
	if [ "$DEVID" = "$AIN" ]; then
		DEVINFO="<"$DEV
		break;
	fi
 done
 #DEVINFO=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getdeviceinfos&sid=$SID" 2>/dev/null`
 TYPE=$(grep_digit_property "$DEVINFO" "functionbitmask")
 DEVICE=-1
 if [ "$DEBUG" = "1" ]; then
	 echo "TYPE = $TYPE"
 fi
 if [[ $TYPE =~ ^[0-9]+$ ]]; then
	if (( $TYPE & 2**9 )); then
		DEVICE=1
	elif (( $TYPE & 2**6 )); then
		DEVICE=2
	elif (( $TYPE & 2**0 )); then
		DEVICE=3
	elif (( $TYPE & 2**5 )); then
		DEVICE=4
 	fi
 fi	
 DATE=`date +%s`
 if [ "$DEVICE" = "1" ]; then
  # Outlet / Switch
  TEMP=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
  TEMP=`echo "scale=1; $TEMP / 10" | bc `
  STATE=$(grep_data "$DEVINFO" "state")

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
  TSOLL=$(grep_data "$DEVINFO" "tsoll")
  TSOLL=$(( (TSOLL-16)/2 + 8 ))
  WOPEN=$(grep_data "$DEVINFO" "windowopenactiv")
  WOPENTIME=$(grep_data "$DEVINFO" "windowopenactiveendtime")
  BATTERY=$(grep_data "$DEVINFO" "battery")
  BOOST=$(grep_data "$DEVINFO" "boostactive")
  BOOSTTIME=$(grep_data "$DEVINFO" "boostactiveendtime")
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
  SUBTYPE=$(grep_digit_property "$DEVDETAILS" "functionbitmask")
  SUBDEVICE=-1
  if (( $SUBTYPE & 2**18 )); then
	SUBDEVICE=31
  fi
  if [ "$SUBDEVICE" = "31" ]; then
   LEVEL=$(grep_data "$DEVDETAILS" "levelpercentage")
   if [ "$DEBUG" = "1" ]; then
    printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$SUBDEVICE\">\n<level>$LEVEL</level>\n$DEVDETAILS\n</device>\n"
   else
    printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$SUBDEVICE\">\n<level>$LEVEL</level>\n$DEVDETAILS\n</device>\n" >> $TMP_FILE
   fi
  fi
 elif [ "$DEVICE" = "4" ]; then
  TEMP=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=gettemperature&sid=$SID" 2>/dev/null `
  TEMP=`echo "scale=1; $TEMP / 10" | bc `
  BATTERY=$(grep_data "$DEVINFO" "battery")
  HUMIDITY=$(grep_data "$DEVINFO" "rel_humidity")
  DETAILS=`curl "$box/webservices/homeautoswitch.lua?ain=$AIN&switchcmd=getbasicdevicestats&sid=$SID" 2>/dev/null `
  if [ "$DEBUG" = "1" ]; then
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<battery>$BATTERY</battery>\n<humidity>$HUMIDITY</humidity>\n$DEVINFO\n</device>\n"
   printf "T=$TEMP,B=$BATTERY,H=$HUMIDITY,Z=$DATE;\n"
  else
   printf "<device ain=\"$AIN\" name=\"$NAME\" type=\"$DEVICE\">\n<temp>$TEMP</temp>\n<battery>$BATTERY</battery>\n<humidity>$HUMIDITY</humidity>\n$DETAILS\n</device>\n" >> $TMP_FILE
   printf "T=$TEMP,B=$BATTERY,H=$HUMIDITY,Z=$DATE;\n" >> "$OUTPUT_30SEC$AIN.data"
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
