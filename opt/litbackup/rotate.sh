#!/bin/bash

# Copyright 2014, Vytenis Sabaliauskas <vytenis.adm@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http:/www.gnu.org/licenses/> for
# more details.


source /etc/litbackup/$SERVER/main.cfg 2>/dev/null
source /etc/litbackup/$FLAVOR/main.cfg || exit 1
source /etc/litbackup/$SERVER/main.cfg 2>/dev/null

LOGPREFIX="LitBackup $SERVER rotate.sh"
function log {
while read DATA; do
    echo $DATA|logger -t "$LOGPREFIX" -p daemon.info
done
}

function logerror {
while read DATA; do
        echo $DATA|logger -t "$LOGPREFIX" -p daemon.err
done
}

if [ ! -d $BACKUPDIR ] ; then
    echo "there is no $BACKUPDIR directory. Exiting..."|log
    exit 1
fi

if [ $LASTBACKUP -eq 0 ] ; then
    echo "no successfull backups found (LASTBACKUP=1). Exiting..." |logerror
    exit 1
fi

LASTSUCCESSHOUR=`date -d @$LASTBACKUP '+%H'`
LASTSUCCESSDATE=`date -d @$LASTBACKUP '+%Y-%m-%d'`
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

if [ -d $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX ] ; then
    echo "there already is a directory named $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX. Renaming it to older..." |log
    mv -fv $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX $BACKUPROOT/$SERVER/$DATEOFBACKUP-older-$PREFIX |log
fi

echo $$ > /var/spool/litbackup/$SERVER/rotate.pid
rm -f /var/spool/litbackup/$SERVER/lastrotatesuccess.timestamp

echo  "starting to rotate $BACKUPDIR to $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX" |log
mkdir $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX
echo  "hard-linking $BACKUPDIR to $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX/..." |log

cp -al $BACKUPDIR/* $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX/ ; STATUS=$?
if [ $STATUS -ne 0 ] ; then
	echo "hardlinking cp -al $BACKUPDIR $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX failed. Exiting..." |logerror
	exit 1
else
	echo "done hardlinking." |log
fi

while [ `find $BACKUPROOT/$SERVER  -maxdepth 1 -type d -name "*-$PREFIX"|wc -l` -gt $DELETEOLDER ] ; do
	OLDEST=`find $BACKUPROOT/$SERVER/  -maxdepth 1 -type d -name "*-$PREFIX"|sort -n|head -n 1`
	echo "number of $PREFIX backups exceeded $DELETEOLDER, removing $OLDEST backup ..." |log
	[ -d $OLDEST ] && [ ! -z $OLDEST ] && rm -rf $OLDEST && echo "done removing $OLDEST" |log
done

if [ "x$COMPRESSFILES" == "xyes" ] ; then
    echo "Please use \"/opt/litbackup/utils/find-compressed-backups.sh\" or \"find -name \"*$GZIPSUFFIX\" on the directory You are trying to restore to make sure that all files are decompressed" > $BACKUPROOT/$SERVER/WARNING-README
    echo "To list - run \"find <restored_directory> -type f -name \"*$GZIPSUFFIX\"\"" >> $BACKUPROOT/$SERVER/WARNING-README
    DIRTOCOMPRESS=`date -d "$DATEOFBACKUP - 1 day" '+%Y-%m-%d'`
    if `ls $BACKUPROOT/$SERVER/$DIRTOCOMPRESS-* &> /dev/null` ; then
		echo "find $BACKUPROOT/$SERVER/$DIRTOCOMPRESS-*/ $COMPRESSFINDPARAMS"|sh && echo "Finished compressing files in $BACKUPROOT/$SERVER/$DIRTOCOMPRESS-* ..." |log
    else
		echo "directory $BACKUPROOT/$SERVER/$DIRTOCOMPRESS-* not found. Skipping compression..." |log
    fi
fi
if [ "x$COMPRESSFILES" != "xyes" ] && [ -f $BACKUPROOT/$SERVER/WARNING-README ] ; then
    rm -f -I $BACKUPROOT/$SERVER/WARNING-README
fi

if [ "x$BACKUPPERMISSIONS" == "xyes" ] ; then
	[ ! -d $BACKUPROOT/$SERVER/file-metadata-backups/ ] && mkdir -p $BACKUPROOT/$SERVER/file-metadata-backups/
	if [ -f $BACKUPROOT/$SERVER/file-metadata-backups/$DATEOFBACKUP-$PREFIX-file-permissions.gz ] ; then
		echo "there already is a file named $BACKUPROOT/$SERVER/file-metadata-backups/$DATEOFBACKUP-$PREFIX-file-permissions.gz. Renaming..." |log
		mv -fv $BACKUPROOT/$SERVER/file-metadata-backups/$DATEOFBACKUP-$PREFIX-file-permissions.gz $BACKUPROOT/$SERVER/file-metadata-backups/$DATEOFBACKUP-older-$PREFIX-file-permissions.gz |log
	fi
	cd $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX/
	find * -printf '%m:%U:%G:%p\n' |gzip > $BACKUPROOT/$SERVER/file-metadata-backups/$DATEOFBACKUP-$PREFIX-file-permissions.gz
	echo "Done making a backup of $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX permissions and owners to $BACKUPROOT/$SERVER/file-metadata-backups/$DATEOFBACKUP-$PREFIX-file-permissions.gz." |log
fi

while [ `find $BACKUPROOT/$SERVER/file-metadata-backups/ -maxdepth 1 -type f -name "*-$PREFIX-file-permissions.gz"|wc -l` -gt $DELETEOLDER ] ; do
	OLDEST=`find $BACKUPROOT/$SERVER/file-metadata-backups/ -maxdepth 1 -type f -name "*-$PREFIX-file-permissions.gz"|sort -n|head -n 1`
	[ -f $OLDEST ] && [ ! -z $OLDEST ] && echo "number of $PREFIX file-metadata-backups exceeded $DELETEOLDER, removing $OLDEST file metadata ..." |log && rm -fv -I $OLDEST|log && echo "done removing $OLDEST" |log
done


date +%s > /var/spool/litbackup/$SERVER/lastrotatesuccess.timestamp
rm -fv /var/spool/litbackup/$SERVER/rotate.pid|log
echo "Rotate to $BACKUPROOT/$SERVER/$DATEOFBACKUP-$PREFIX/ finished! Success!"|log

#Cleaning possible spool system leftovers:
for SPOOLDIR in $(ls -1 /var/spool/litbackup 2>/dev/null);
    do
	grep $SPOOLDIR /etc/litbackup/servers.cfg > /dev/null || rm -rfv /var/spool/litbackup/$SPOOLDIR |log
    done