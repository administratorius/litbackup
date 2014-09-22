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
source $CURRENTDIR/../config/main.cfg


if [ "x$1" == "x" ] || [ ! -d $1 ] ; then
    echo "Usage: $0 <directory to find and decompress backups named with $GZIPSUFFIX>"
fi

find $1 -type f -name "*$GZIPSUFFIX" -exec gzip -v -d -N {} \;


