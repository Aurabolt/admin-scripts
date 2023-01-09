#!/bin/bash
SCRIPTNAME=`basename "$0"`
LOGFILE=/root/$SCRIPTNAME.log
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -d "/var/www" ]; then
  APPNAME=`ls /var/www | grep -v html | head -n 1`
  if [[ ! -z "$APPNAME" ]]; then
    APPDIR=/var/www/$APPNAME
    echo "appname is $APPNAME, appdir is $APPDIR"
  fi
fi

if [ "$EUID" -ne 0 ]; then
  echo "$SCRIPTNAME must run as root"
  exit
fi

echo
echo $(date)

# Make sure crontab auto starts "php artisan up" after reboots
CRONRESULT=$(sudo crontab -l | grep "admin-scripts" | grep "git pull")
if [[ -z $CRONRESULT ]]; then
  echo "Installing 'git pull' for /root/admin-scripts to crontab..."
  (crontab -l ; echo "0 * * * * cd /root/admin-scripts; git pull") | crontab -
fi

# Kill currently running apt upgrade processes
# https://stackoverflow.com/a/3510850
APTRUNNINGRESULT=$(ps aux | grep 'apt upgrade' | grep -v grep)
if [[ ! -z $APTRUNNINGRESULT ]]; then
  echo "Killing all 'apt upgrade' processes..."
  kill $(ps aux | grep 'apt upgrade' | grep -v grep | awk '{print $2}')
fi

# apt update
sudo apt update

if [[ ! -z $APPDIR ]]; then
  # Make sure crontab auto starts "php artisan up" after reboots
  CRONRESULT=$(sudo crontab -l | grep "php artisan up")
  if [[ -z $CRONRESULT ]]; then
    echo "Installing 'php artisan up' after reboots to crontab..."
    (crontab -l ; echo "@reboot cd $APPDIR && php artisan up") | crontab -
  fi
fi

# Update pihole if pihole binary exists
PIHOLE=/usr/local/bin/pihole

if [ -f $PIHOLE ]; then
  echo "Updating pihole..."
  $PIHOLE -up
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

  # Upgrade
  echo "Doing apt upgrades..."
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" upgrade

  # Cleanup (Commented out 1/9/2023 for breaking php8.1-redis)
  # sudo apt autoclean -y
  # sudo apt autoremove -y

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
