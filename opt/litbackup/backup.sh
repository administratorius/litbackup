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

#Let's read the config file (order is important!):
source /etc/litbackup/$SERVER/main.cfg 2>/dev/null
source /etc/litbackup/$FLAVOR/main.cfg || exit 1
source /etc/litbackup/$SERVER/main.cfg 2>/dev/null

LOGPREFIX="LitBackup $SERVER backup.sh"
[ -z $SSHTO ] && export SSHTO=$SERVER
function log {
while read DATA; do
    echo $DATA|logger -t "$LOGPREFIX" -p daemon.info
done
}

function do-cleanup {
[ -f $NORECURSEDIRS ] && rm -fv -I $NORECURSEDIRS|log
[ -f $FILESLIST ] && rm -fv -I $FILESLIST|log
echo "Removed temporary files."|log
echo "Backup of $SERVER finished successfully! Yay!"|log
mv -fv /var/spool/litbackup/$SERVER/lastbackupstarted.timestamp /var/spool/litbackup/$SERVER/lastbackupsuccess.timestamp | log
MYHOSTNAME=`hostname -f`
scp -i $SSHPRIVATEKEY -P $SSHPORT /var/spool/litbackup/$SERVER/lastbackupsuccess.timestamp $SSHUSER@$SSHTO:/var/run/latest-backup-on-$MYHOSTNAME
rm -fv -I /var/spool/litbackup/$SERVER/backup.pid | log
}

function logerror {
while read DATA; do
	echo $DATA|logger -t "$LOGPREFIX" -p daemon.err
	[ -f $NORECURSEDIRS ] && rm -f -I $NORECURSEDIRS
	[ -f $FILESLIST ] && rm -f -I $FILESLIST
	[ -f $FILESLIST.tmp ] && rm -f -I $FILESLIST.tmp
	[ -f $FILESLIST.tmp2 ] && rm -f -I $FILESLIST.tmp2
	rm -fv -I /var/spool/litbackup/$SERVER/backup.pid
done
}

function do-backup {
    RSYNCCMD="/bin/false"
    case "$1" in
        full)
            RSYNCCMD=$FULLRSYNC
            ;;
        regular)
            RSYNCCMD=$REGULARRSYNC
            ;;
        non-recursive)
            RSYNCCMD=$NORECURSIONRSYNC
    esac
    echo "Command to execute:"|log
    echo $RSYNCCMD|log
    echo "Starting $1 rsync ..."|log
    echo $RSYNCCMD|sh; STATUS=$?
    if [ $STATUS != 0 ] && [ $STATUS != 23 ] && [ $STATUS != 24 ] ; then
                echo "... exiting $1 rsync."|log
                echo "$1 rsync FAILED, exit status code $STATUS. Aborting backup job."|logerror
                exit $STATUS
    else
                echo "... $1 rsync done."|log
    fi
}

if [ $LASTBACKUP -ne 0 ] ; then
    NOW=`date +%s`
    TIMESINCELASTSUCCESS=$((NOW-LASTBACKUP))
    TIMESINCELASTSUCCESS=$((TIMESINCELASTSUCCESS/60))
    TIMESINCELASTSUCCESS=$((TIMESINCELASTSUCCESS+1)) #+1 to bypass "find" rounding of numbers
fi

if [ ! -d /var/spool/litbackup/$SERVER ] ; then
	LASTBACKUP=0
	mkdir -p /var/spool/litbackup/$SERVER ; STATUS=$? ; [ $STATUS -ne 0 ] && echo "FAILED TO CREATE /var/spool/litbackup/$SERVER. mkdir exit status $STATUS. Exiting."|logerror && exit $STATUS
	echo "created directory /var/spool/litbackup/$SERVER" |log
fi


if [ ! -d $BACKUPDIR ] ; then
	LASTBACKUP=0
	mkdir -p $BACKUPDIR ; STATUS=$? ; [ $STATUS -ne 0 ] && echo "FAILED TO CREATE $BACKUPDIR. mkdir exit status $STATUS. Exiting."|logerror && exit $STATUS
	echo "created directory $BACKUPDIR - this is a full initial backup" |log
fi

if [ "x$FORCEFULLON" != "x" ] && [ $FORCEFULLON -eq `date +%d` ] ; then
    LASTBACKUP=0
    echo "today the full backup is forced by FORCEFULLON=$FORCEFULLON"|log
fi

echo $$ > /var/spool/litbackup/$SERVER/backup.pid
date +%s > /var/spool/litbackup/$SERVER/lastbackupstarted.timestamp

if [ $LASTBACKUP -eq 0 ] ; then
    do-backup full
    do-cleanup
    exit;
fi

$FILELISTGENERATOR $TIMESINCELASTSUCCESS ; STATUS=$? ; [ $STATUS -ne 0 ] && echo "FAILURE WHILE EXECUTING $FILELISTGENERATOR -  exit status $STATUS. Exiting."|logerror && exit $STATUS

do-backup regular
if [ -f $NORECURSEDIRS ] ; then
	do-backup non-recursive
fi
do-cleanup