#!/bin/bash
SCRIPTNAME=`basename "$0"`
LOGFILE=/root/$SCRIPTNAME.log
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

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

echo
echo $(date)
sudo apt update

if [[ ! -z $APPDIR ]]; then
  # Make sure crontab auto starts "php artisan up" after reboots
  CRONRESULT=$(sudo crontab -l | grep -i "php artisan up")
  if [[ -z $CRONRESULT ]]; then
    echo "Installing 'php artisan up' after reboots to crontab..."
    (crontab -l ; echo "@reboot cd $APPDIR && php artisan up") | crontab -
  fi
fi

# Update pihole
PIHOLE=$(which pihole)

if [ $? -eq 0 ]; then
  echo "Updating pihole..."
  pihole -up
fi

APTRESULT=$(sudo apt list --upgradeable | wc -l)
if [[ $APTRESULT -gt 1 ]]; then
  echo "-----------------------------"
  echo "apt updates found! Updating..."

  if [[ ! -z $APPDIR ]]; then
    echo "cd to $APPDIR, appname is $APPNAME"
    cd $APPDIR
    php artisan down --retry=60 --redirect=/
  fi
  
  # Backup
  if [ -f $APPDIR/backup-app.sh ]; then
    $APPDIR/backup-app.sh
  fi

  echo "Doing apt updates..."
  sudo apt upgrade -y

  # Check if upgrade failed
  if [ $? -eq 0 ]; then
    echo "Upgrades finished OK."
  else
    echo "ERROR: Upgrades failed! Quitting."
    exit 2
  fi

  # Reboot if needed
  if [[ "$1" == "reboot-if-needed" ]]; then
    $SCRIPT_DIR/reboot-if-needed.sh
  fi

  if [[ ! -z $APPDIR ]]; then
    echo "cd to $APPDIR, appname is $APPNAME"
    cd $APPDIR
    $APPDIR/restart-app.sh --nolog true
    php artisan up
  fi
else
  echo "No apt updates found."
fi
