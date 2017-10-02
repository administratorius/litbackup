#!/bin/bash

# Copyright 2014, Vytenis Sabaliauskas <vytenis.adm@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.

LOGPREFIX="LitBackup cron.sh"
function log {
while read DATA; do
    echo $DATA|logger -t "$LOGPREFIX" -p daemon.info
    done
}

[ ! -f /etc/litbackup/cron.cfg ] && echo "ERROR: /etc/litbackup/cron.cfg does not exist"|log && exit 1
[ ! -f /etc/litbackup/servers.cfg ] && echo "ERROR: /etc/litbackup/servers.cfg does not exist"|log && exit 1


#Let's read cron.cfg:
source /etc/litbackup/cron.cfg


for CHECKPIDFILE in `ls /var/spool/litbackup/*/*.pid 2>/dev/null`;
    do
	PID=`cat $CHECKPIDFILE`
	SPOOLDIR=`dirname $CHECKPIDFILE`
	[ ! -d /proc/$PID ] && [ -d $SPOOLDIR ] && echo "PID $PID does not exist, removing everything from $SPOOLDIR/*"|log && rm -fv $SPOOLDIR/* |log
    done

JOBCOUNT=`ls /var/spool/litbackup/*/*.pid 2>/dev/null|wc -l`
[ "$JOBCOUNT" -ge "$MAXJOBS" ] && echo "Maximum number of jobs allowed - $MAXJOBS, jobs running - $JOBCOUNT , exiting..."|log && exit 0

HOUR=`date +%H`

cat /etc/litbackup/servers.cfg|grep -v '#'| xargs -0 -L1 echo |while read SERVER FLAVOR
    do
	[ ! -n "$SERVER" ] && continue
	[ ! -n "$FLAVOR" ] && FLAVOR=$DEFAULTFLAVOR
	export SERVER
	export FLAVOR
	LASTROTATE=1
	LASTBACKUP=0
	[ -f /var/spool/litbackup/$SERVER/lastrotatesuccess.timestamp ] && LASTROTATE=`cat /var/spool/litbackup/$SERVER/lastrotatesuccess.timestamp`
	[ -f /var/spool/litbackup/$SERVER/lastbackupsuccess.timestamp ] && LASTBACKUP=`cat /var/spool/litbackup/$SERVER/lastbackupsuccess.timestamp`
	export LASTROTATE
	export LASTBACKUP
	if [ "$HOUR" -ge "$ROTATEMINHOUR" -a "$HOUR" -le "$ROTATEMAXHOUR" ] ; then
		[ -f /var/spool/litbackup/$SERVER/rotate.pid ] && continue
		[ ! -f /var/spool/litbackup/$SERVER/backup.pid ] && [ "$LASTROTATE" -le "$LASTBACKUP" ] && /opt/litbackup/rotate.sh && exit
	else
		[ -f /var/spool/litbackup/$SERVER/backup.pid ] && continue
		[ ! -f /var/spool/litbackup/$SERVER/rotate.pid ] && [ "$LASTROTATE" -ge "$LASTBACKUP" ] && /opt/litbackup/backup.sh && exit
	fi
    done