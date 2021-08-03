#!/bin/bash
SCRIPTNAME=`basename "$0"`
LOGFILE=/root/$SCRIPTNAME.log

if [ -d /var/www ]; then
  WWW=`ls /var/www | grep -v html | head -n 1`
  APPDIR=/var/www/$WWW
fi

if [ "$EUID" -ne 0 ]
  then echo "$SCRIPTNAME must run as root"
  exit
fi

echo $(date) | tee $LOGFILE


if [ -f /var/run/reboot-required ]; then
  echo "Reboot required! Rebooting now..." | tee $LOGFILE
  sudo reboot
else
  echo "No reboot required." | tee $LOGFILE
fi
