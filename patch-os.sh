#!/bin/bash
SCRIPTNAME=`basename "$0"`
LOGFILE=/root/$SCRIPTNAME.log
#APPNAME=/nothing
#APPDIR=/nothing

if [ -d "/var/www" ]; then
  APPNAME=`ls /var/www | grep -v html | head -n 1`
  if [[ ! -z "$APPNAME" ]]; then
    echo "appname is $APPNAME, appdir is $APPDIR"
    APPDIR=/var/www/$APPNAME
  fi
fi

if [ "$EUID" -ne 0 ]; then 
  echo "$SCRIPTNAME must run as root"
  exit
fi

echo $(date) | tee $LOGFILE
sudo apt update

APTRESULT=$(sudo apt list --upgradeable | wc -l)
if [[ $APTRESULT -gt 1 ]]; then
  echo "-----------------------------"
  echo "apt updates found! Updating..." | tee $LOGFILE

  if [[ ! -z $APPDIR ]]; then
    echo "cd to $APPDIR, appname is $APPNAME"
    cd $APPDIR
    php artisan down --retry=60 --redirect=/
  fi
  
  # Backup
  if [ -f $APPDIR/backup-app.sh ]; then
    $APPDIR/backup-app.sh
  fi

  echo "Doing apt updates..." | tee $LOGFILE
  sudo apt upgrade -y
else
  echo "No apt updates found." | tee $LOGFILE
fi
