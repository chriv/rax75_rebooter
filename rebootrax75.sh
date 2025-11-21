#!/bin/bash
# Name: rebootrax75.sh
# Date: 2025-11-21 (Refactored)
# Author: Chuck Renner
# License: MIT License
# Version 0.3.0

# --- CONFIG LOADING ---
# 1. Check for local config (dev/testing)
# 2. Check for installed config (production)
OVERRIDE_DRY_RUN=${DRY_RUN:-}
if [[ -f "./config.env" ]]; then
    source "./config.env"
elif [[ -f "/etc/rebootrax75/config.env" ]]; then
    source "/etc/rebootrax75/config.env"
else
    echo "Error: Configuration file not found." >&2
    exit 1
fi
if [[ -n "$OVERRIDE_DRY_RUN" ]]; then
    DRY_RUN="$OVERRIDE_DRY_RUN"
fi
# ----------------------

# Exit if script is not running with root privileges.
if [ `id -u` -ne 0 ]; then
  echo "Run this script using sudo!"
  exit 1
fi

# Define functions
function str_random() {
    array=()
    for i in {a..z} {A..Z} {0..9}; do
        array[$RANDOM]=$i
    done
    printf %s ${array[@]::8}
}

function urlencode() {
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:$i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    LC_COLLATE=$old_lc_collate
}

function urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

INSECURE_OPTION=
VERBOSE_OPTION=
if [ ${INSECURE:-0} -eq 1 ]; then INSECURE_OPTION=--insecure; fi
if [ ${VERBOSE:-0} -eq 1 ]; then VERBOSE_OPTION=--verbose; fi

# Temporary directory
DUMPDIR=/tmp
# WAP Fully Qualified Domain Name (FQDN)
WFQDN=$WHOST.$WDOM
# Cookie Jar file
JAR=$DUMPDIR/$WHOST.cjar
# Curl output files prefix
OUT=$DUMPDIR/$WHOST
# URL encode the printer username and password
WUSER_ENC=$(urlencode "$WUSER")
WPASS_ENC=$(urlencode "$WPASS")

echo Logging into WAP
if [ ${VERBOSE:-0} -eq 1 ]; then
  echo Running curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u \"$WUSER_ENC:\<\$WPASS_ENC\>\" \"https://$WFQDN/\"
fi
curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u "$WUSER_ENC:$WPASS_ENC" "https://$WFQDN/" --output - 1>$OUT-1.html 2>$OUT-1.err
chmod 600 $JAR
chmod 600 $OUT-1.*

if [ ${VERBOSE:-0} -eq 1 ]; then
  echo Running curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u \"$WUSER_ENC:\<\$WPASS_ENC\>\" \"https://$WFQDN/ADVANCED_home.htm\"
fi
curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u "$WUSER_ENC:$WPASS_ENC" "https://$WFQDN//ADVANCED_home.htm" --output - 1>$OUT-2.html 2>$OUT-2.err
chmod 600 $OUT-2.*

if [ ${VERBOSE:-0} -eq 1 ]; then
  echo Running curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u \"$WUSER_ENC:\<\$WPASS_ENC\>\" --referer \"https://$WFQDN/ADVANCED_home.htm\" \"https://$WFQDN/ADVANCED_home1.htm\"
fi
curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u "$WUSER_ENC:$WPASS_ENC" --referer "https://$WFQDN/ADVANCED_home.htm" "https://$WFQDN/ADVANCED_home1.htm" --output - 1>$OUT-3.html 2>$OUT-3.err
chmod 600 $OUT-3.*

if [ ${VERBOSE:-0} -eq 1 ]; then
  echo Getting form id from curl...
fi
FORM_ACTION=`curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u "$WUSER_ENC:$WPASS_ENC" --referer "https://$WFQDN/ADVANCED_home1.htm" "https://$WFQDN/ADVANCED_home2.htm" --output - 2>$OUT-4.err | grep newgui_adv_home.cgi | sed 's/^.*\(newgui_adv_home.cgi?id=[a-f0-9]\+\).*$/\1/'`
chmod 600 $OUT-4.*

if [ ${VERBOSE:-0} -eq 1 ]; then
  echo Set FORM_ACTION to $FORM_ACTION
fi

echo Attempting reboot of WAP
if [ ${DRY_RUN:-0} -eq 1 ]; then
  FORM_BUTTON=
else
  FORM_BUTTON='--form "buttonSelect=2"'
fi

# The reboot command
curl $VERBOSE_OPTION $INSECURE_OPTION --cookie-jar $JAR --cookie $JAR -u "$WUSER_ENC:$WPASS_ENC" --referer "https://$WFQDN/ADVANCED_home2.htm" $FORM_BUTTON "https://$WFQDN/$FORM_ACTION" --output - 1>$OUT-Final.html 2>$OUT-Final.err
chmod 600 $OUT-Final.*

echo "WAP should be rebooting; WLAN should be offline for about 2 minutes"

# Cleanup
rm -f $JAR $OUT-?.*
echo "Results highlights from WAP reboot information page:"
grep 'The router is rebooting' $OUT-Final.html || echo "Reboot confirmation not found (check logs)."
rm -f $OUT-Final.*
echo "Completed WAP reboot script"
