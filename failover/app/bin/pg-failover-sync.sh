#!/bin/bash

HOST=$1
USERNAME=$2
PASSWORD=$3

echo "Getting latest backup from failover master"
mkdir -p /tmp/upguard
curl -k https://$USERNAME:$PASSWORD@$HOST/backups/latest.tar.gz > /tmp/upguard/latest_backup.tar.gz

if [ $? -eq 0 ]; then
		echo "Stopping relevant services"
		fleetctl stop postgres postgres-discovery secure secure-discovery
		
		echo "Untarring database backup"
		sudo tar -xzf /tmp/upguard/latest_backup.tar.gz -C /media/database/upguard/
		
		echo "Starting relevant services"
		fleetctl start postgres postgres-discovery secure secure-discovery
		
		echo "Writing timestamp html"
		TIMESTAMP="`curl -sk https://$USERNAME:$PASSWORD@$HOST/backups/ | grep latest.tar.gz | awk '{ print $3 " " $4 }'`"
		sudo bash -c 'echo "Most recent backup timestamp on $0: $1 $2" > /www/secure/public/latest_db_sync.html' $HOST $TIMESTAMP
fi

echo "Cleanup"
rm -rf /tmp/upguard
