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

function do-cleanup {
[ -f $NORECURSEDIRS ] && rm -f -I $NORECURSEDIRS
[ -f $FILESLIST ] && rm -f -I $FILESLIST
[ -f $STATUSFILE-LASTFAIL ] && rm -f -I $STATUSFILE-LASTFAIL
echo "Removed temporary files."|log
echo "Backup of $SERVER finished successfully! Yay!"|log
mv -f $STATUSFILE $STATUSFILE-LASTSUCCESS
rm -f -I $LOCKFILE
}

function logerror {
while read DATA; do
	echo `date +%s` `date +%Y-%m-%d\ %H:%M:%S` "$LOGPREFIX ERROR: $DATA"|tee -a $STATUSFILE
	[ -f $NORECURSEDIRS ] && rm -f -I $NORECURSEDIRS
	[ -f $FILESLIST ] && rm -f -I $FILESLIST
	[ -f $FILESLIST.tmp ] && rm -f -I $FILESLIST.tmp
	[ -f $FILESLIST.tmp2 ] && rm -f -I $FILESLIST.tmp2
	mv -fv $STATUSFILE $STATUSFILE-LASTFAIL
	rm -f -I $LOCKFILE
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
    echo "Starting $1 rsync"|log
    echo "Command to execute:"|log
    echo $RSYNCCMD|log
    echo "############## Start of $1 rsync log:"|log
    echo $RSYNCCMD|sh; STATUS=$?
    if [ $STATUS != 0 ] && [ $STATUS != 24 ] ; then
		echo "############## ...end of $1 rsync log."|log
		echo "$1 BACKUP job FAILED, rsync exited with status code $STATUS. Exiting."|logerror
		exit $STATUS
    else
		echo "############## ...end of $1 rsync log."|log
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
do-cleanup
    if [ "x$FORCEAFTERFAILED" == "xyes" ] ; then
    	echo "file $STATUSFILE-LASTFAIL exists, last backup has failed. Please check $STATUSFILE-LASTFAIL. Continuing because FORCEAFTERFAILED=yes ..."|log
    else
    	echo "file $STATUSFILE-LASTFAIL exists, last backup has failed. Please check and remove $STATUSFILE-LASTFAIL. FORCEAFTERFAILED in main.cf is not set to \"yes\"  Exiting..."|log
    	exit 1
    fi
fi

if [ -f $STATUSFILE-LASTSUCCESS ] ; then
    LASTSUCCESS=`head -n 1 $STATUSFILE-LASTSUCCESS|awk '{ print $1}'`
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