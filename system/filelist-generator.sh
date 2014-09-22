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
source $CURRENTDIR/../config/main.cfg



BACKUPDIRS=`echo $DIRSTOBACKUP|tr -d ':'` 

LOGPREFIX="filelist-generator:"
function log {
while read DATA; do
    echo `date +%s` `date +%Y-%m-%d\ %H:%M:%S` "$LOGPREFIX $DATA"|tee -a $STATUSFILE
    done
}


LASTRUNMINS=$1
if [ "x$FILESLIST" == "x" ] || [ "x$LASTRUNMINS" == "x" ] ; then
    echo "wrong parameters given - please don't run this manually"|log
    exit 1
fi

#Command used to find files to backup. "find" in this case. Feel tree to generate TMPFILE the way You like. It needs to be sorted for cleanup (see below):
echo "executing \"find $BACKUPDIRS -mount -cmin -$LASTRUNMINS\" on $SERVER"|log
ssh -i $SSHPRIVATEKEY -p $SSHPORT -o StrictHostKeyChecking=no $SSHUSER@$SERVER "find $BACKUPDIRS -mount -cmin -$LASTRUNMINS"|sort > $FILESLIST.tmp
STATUS=${PIPESTATUS[0]}
if [ $STATUS -ne 0 ] ; then
    echo "ssh returned error $STATUS. Exiting..."|log
    exit $STATUS
fi


#Initial values and setup:
PREVIOUS="JHSdiuagiKUJG45IUYtsok345jhxcgkUH6537648tiyKJHGKu"  #To prevent matching of the first line 
cat /dev/null > $FILESLIST
chown root:root $FILESLIST
chmod 600 $FILESLIST


#Cleaning the file list to only contain parent directories (e.g. /dir and /dir/subdir will leave only /dir - deduplicating to speed up recursive rsync):
cat $FILESLIST.tmp|while read line
            do
		 if test "${line#*$PREVIOUS}" == "$line" ; then
                    echo $line >> $FILESLIST
		    PREVIOUS=$line
                 fi
            done
rm -f -I $FILESLIST.tmp
