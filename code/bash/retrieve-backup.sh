#!/bin/bash
# Download nightly backups of the file system backup into a folder for safekeeping
# Usage: retrieve-backup.sh <host url> <username> <password> <output directory>
#
# To run a crontab task, go to your linux/unix terminal and enter the command:
#   crontab -e
# Followed by a cron schedule (in this example, set to 5:00am daily) for the task:
#   0 5 * * * retrieve-backup.sh <host url> <username> <password> <output path>
#
# Please contact your UpGuard technical account manager for the credentials to access
# the backups endpoint of your appliance.
#
# UpGuard Inc <support@upguard.com>

HOST_URL=$1
USERNAME=$2
PASSWORD=$3
OUTPUT_PATH=$4

if [ "$HOST_URL" = "" ] ; then
    echo UpGuard site URL not provided >&2
    echo "Usage: retrieve-backup.sh <host url> <username> <password> <output directory>" >&2
  exit 1
fi

if [ "$USERNAME" = "" ] ; then
    echo Please provide a username >&2
    echo "Usage: retrieve-backup.sh <host url> <username> <password> <output directory>" >&2
  exit 1
fi

if [ "$PASSWORD" = "" ] ; then
    echo Please provide a password >&2
    echo "Usage: retrieve-backup.sh <host url> <username> <password> <output path>" >&2
  exit 1
fi

if [ "$OUTPUT_PATH" = "" ] ; then
    echo Please specify an output directory path to place the downloaded backups >&2
    echo "Usage: retrieve-backup.sh <host url> <username> <password> <output directory>" >&2
  exit 1
fi

DIR=`wget $HOST_URL/backups --user=$ADMIN --password=$PASSWORD --no-check-certificate -O - 2>/dev/null | sed -e 's/^.*\">//' | sed -e 's/\/.*$//' | grep "^2" | tail -1`
wget $HOST_URL/backups/$DIR/base.tar.gz --user=$ADMIN --password=$PASSWORD --no-check-certificate -O $OUTPUT_PATH/$DIR-base.tar.gz
