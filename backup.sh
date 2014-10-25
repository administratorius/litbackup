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

#Let's read the config file:
CURRENTDIR=`dirname "${BASH_SOURCE[0]}"`
source $CURRENTDIR/config/main.cfg

LOGPREFIX="backup:"
function log {
while read DATA; do
    echo `date +%s` `date +%Y-%m-%d\ %H:%M:%S` "$LOGPREFIX $DATA"|tee -a $STATUSFILE
done
}

function logerror {
while read DATA; do
	echo `date +%s` `date +%Y-%m-%d\ %H:%M:%S` "$LOGPREFIX ERROR: $DATA"|tee -a $STATUSFILE
	rm -f -I $LOCKFILE
	[ -f $FILESLIST ] && rm -f -I $FILESLIST
	mv -fv $STATUSFILE $STATUSFILE-LASTFAIL
done
}

function do-backup {
    echo "rsync command to execute:"|log
    echo $@|log
    echo "##############rsync log:"|log
    echo $@|sh; STATUS=$?
    if [ $STATUS != 0 ] && [ $STATUS != 24 ] ; then
		echo "##############rsync log end."|log
		echo "BACKUP FAILED, rsync exited with status code $STATUS. Exiting."|logerror
		exit $STATUS
    else
		echo "##############rsync log end."|log
		echo "backup finished successfully! Yay!"|log
		rm -f -I $LOCKFILE
		[ -f $FILESLIST ] && rm -f -I $FILESLIST
		mv -f $STATUSFILE $STATUSFILE-LASTSUCCESS
		exit 0
    fi
}

if [ -f $LOCKFILE ] ; then
    PIDOFBACKUP=`cat $LOCKFILE`
    if [ "x$PIDOFBACKUP" != "x" ] && [ -e "/proc/$PIDOFBACKUP" ] ; then
		echo "backup job is still running (PID: $PIDOFBACKUP). Exiting..."|log
		exit;
    else
		echo "backup job is stalled. PID $PIDOFBACKUP does not exist. Removing $LOCKFILE and continuing as usual..."|log
		rm -f -I $LOCKFILE
    fi
fi

if [ -f $STATUSFILE-LASTFAIL ] ; then
    if [ "x$FORCEAFTERFAILED" == "xyes" ] ; then
    	echo "file $STATUSFILE-LASTFAIL exists, last backup has failed. Please check $STATUSFILE-LASTFAIL. Continuing because FORCEAFTERFAILED=yes ..."|log
    else
    	echo "file $STATUSFILE-LASTFAIL exists, last backup has failed. Please check and remove $STATUSFILE-LASTFAIL. FORCEAFTERFAILED in main.cf is not set to \"yes\"  Exiting..."|log
    	exit 1
    fi
fi

if [ -f $STATUSFILE-LASTSUCCESS ] ; then
    LASTSUCCESS=`grep -i "finished success" $STATUSFILE-LASTSUCCESS|awk '{ print $1}'` 
    cat /dev/null > $STATUSFILE
    NOW=`date +%s`
    TIMESINCELASTSUCCESS=$((NOW-LASTSUCCESS))
    TIMESINCELASTSUCCESS=$((TIMESINCELASTSUCCESS/60))
    TIMESINCELASTSUCCESS=$((TIMESINCELASTSUCCESS+1)) #+1 to bypass "find" rounding of numbers
else
    TIMESINCELASTSUCCESS=-1
fi

if [ "x$FORCEFULLON" != "x" ] && [ $FORCEFULLON -eq `date +%d` ] ; then
    TIMESINCELASTSUCCESS=-1
    echo "today the full backup is forced by FORCEFULLON=$FORCEFULLON"|log
fi

echo $$ > $LOCKFILE

if [ ! -d $BACKUPDIR ] || [ $TIMESINCELASTSUCCESS -eq -1 ] ; then
    if [ ! -d $BACKUPDIR ] ; then
		echo "creating directory $BACKUPDIR for full backup" |log 
		mkdir -p $BACKUPDIR ; STATUS=$? ; [ $STATUS -ne 0 ] && echo "FAILED TO CREATE $BACKUPDIR. mkdir exit status $STATUS. Exiting."|logerror && exit $STATUS
    fi
    do-backup $FULLRSYNC
fi

$FILELISTGENERATOR $TIMESINCELASTSUCCESS ; STATUS=$? ; [ $STATUS -ne 0 ] && echo "FAILURE WHILE EXECUTING $FILELISTGENERATOR -  exit status $STATUS. Exiting."|logerror && exit $STATUS

do-backup $REGULARRSYNC
