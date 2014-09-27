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

CURRENTDIR=`dirname "${BASH_SOURCE[0]}"`
source $CURRENTDIR/config/main.cfg

SERVERBACKUPS=`dirname $BACKUPDIR`

LOGPREFIX="rotate-backups:"
function log {
while read DATA; do
    echo `date +%s` `date +%Y-%m-%d\ %H:%M:%S` "$LOGPREFIX $DATA"|tee -a $STATUSFILE
    done
}

function logerror {
while read DATA; do
        echo `date +%s` `date +%Y-%m-%d\ %H:%M:%S` "$LOGPREFIX ERROR: $DATA"|tee -a $STATUSFILE
	cat $STATUSFILE >> $STATUSFILE-LASTFAIL
done
}

if [ ! -d $BACKUPDIR ] ; then
    echo "there is no $BACKUPDIR directory. Exiting..." |logerror
    exit 1
fi

if [ ! -f $STATUSFILE-LASTSUCCESS ] ; then
    echo "no successfull backups found ($STATUSFILE-LASTSUCCESS doesn't exist). Exiting..." |logerror
    exit 1
fi

if [ -f $STATUSFILE-LASTFAIL ] && [ "x$FORCEAFTERFAILED" != "xyes" ] ; then
    echo "some backups have failed. Please check and remove $STATUSFILE-LASTFAIL. Exiting..." |logerror
    exit 1
fi

if [ -f $LOCKFILE ] ; then
    echo "backup job is still running ($LOCKFILE exists)" |log
    exit
fi

LASTSUCCESSDATE=`grep "backup finished succes" $STATUSFILE-LASTSUCCESS | awk '{print $2}'`
LASTSUCCESSHOUR=`grep "backup finished succes" $STATUSFILE-LASTSUCCESS | awk '{print $3}'|awk -F ':' '{print $1}'`
DATEOFBACKUP=$LASTSUCCESSDATE
if [ $LASTDAYBEFOREHOUR -gt $LASTSUCCESSHOUR ] ; then
    DATEOFBACKUP=`date -d "$LASTSUCCESSDATE - 1 day" '+%Y-%m-%d'`
fi

PREFIX="daily"
DELETEOLDER=$NUMOFDAILY

if [ `date +%u` -eq $WEEKLYDAY ]; then
    PREFIX="weekly"
    DELETEOLDER=$NUMOFWEEKLY
fi

if [ `date +%d` -eq $MONTHLYDAY ]; then
    PREFIX="monthly"
    DELETEOLDER=$NUMOFMONTHLY
fi

if [ -d $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX ] ; then
    echo "there already is a directory named $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX. Nothing to do here. Exiting." |logerror
    exit 1
fi

echo  "starting to rotate $BACKUPDIR to $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX" |log
mkdir $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX
echo  "hard-linking $BACKUPDIR to $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX/..." |log

cp -al $BACKUPDIR/* $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX/ ; STATUS=$?
if [ $STATUS -ne 0 ] ; then
	echo "hardlinking cp -al $BACKUPDIR $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX failed. Exiting..." |logerror
	exit 1
else
	echo "done hardlinking." |log
fi

while [ `ls -1 $SERVERBACKUPS|grep $PREFIX|wc -l` -gt $DELETEOLDER ] ; do
	OLDEST=`ls -1 $SERVERBACKUPS|grep $PREFIX|head -n 1`
	echo "number of $PREFIX backups exceeded $DELETEOLDER, removing $SERVERBACKUPS/$OLDEST..." |log
	[ "x$OLDEST" != "x" ] && rm -rfv $SERVERBACKUPS/$OLDEST ; STATUS=$?
	if [ -f $SERVERBACKUPS/$OLDEST-file-permissions.gz ] ; then
		rm -f -I $SERVERBACKUPS/$OLDEST-file-permissions.gz
	fi
	if [ $STATUS -ne 0 ] ; then
	    echo "removing of $OLDEST failed. Exiting..." |logerror
	    exit 1
	else
	    echo "done removing." |log
	fi
fi

if [ "x$COMPRESSFILES" == "xyes" ] ; then
    echo "Please use \"find-compressed-backups.sh\" or \"find -name \"$GZIPSUFFIX\" on the directory You are trying to restore to make sure that all files are decompressed" > $BACKUPROOT/$SERVER-WARNING-README
    DIRTOCOMPRESS=`date -d "$DATEOFBACKUP - 1 day" '+%Y-%m-%d'`
    if [ -d $SERVERBACKUPS/$DIRTOCOMPRESS-* ] ; then
		echo "compressing files in $SERVERBACKUPS/$DIRTOCOMPRESS-* ..." |log
		echo "find $SERVERBACKUPS/$DIRTOCOMPRESS-*/ $COMPRESSFINDPARAMS"|sh ; STATUS=${PIPESTATUS[0]} 
		if [ $STATUS -ne 0 ] ; then
	    	echo "find exit status = $STATUS. Exiting..." |logerror
	    	exit $STATUS
		fi
		echo "done." |log
    	else
		echo "directory $SERVERBACKUPS/$DIRTOCOMPRESS-* not found. Skipping compression..." |log
    fi
fi
if [ "x$COMPRESSFILES" != "xyes" ] && [ -f $BACKUPROOT/$SERVER-WARNING-README ] ; then
    rm -f -I $BACKUPROOT/$SERVER-WARNING-README
fi

if [ "x$BACKUPPERMISSIONS" == "xyes" ] ; then
	cd $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX
	find * -printf '%m:%U:%G:%p\n' |gzip > $SERVERBACKUPS/$DATEOFBACKUP-$PREFIX-file-permissions.gz
fi