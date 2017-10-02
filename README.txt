
* Tested for a year on 40+ physical servers with ~5,000,000 files on each with no problems
* blazingly fast - 5 million files in under 5 minutes (depending on configuration)
* load balancing - backup jobs and maintenance are running separately. You tell when.
* easy on disks - large disks are slow, it uses them wisely
* very intuitive - all backups are folders with dates
* adaptive - just a few configuration options to change. Other options are
  there if You need them.
* simple - written in BASH, requires "rsync" and "find"
* totally FREE - released under GPL v3

Idea:

Make servers find the files to backup by themselves - saves a ton of resources! A simple
but versatile set of scripts.


CURRENT STATUS:

I have a full day/night job and a family, so time is limited. If someone is 
willing to help me fine tune this thing I would like to chat with you. I have
some ideas.

"Documentation":

* "cron.sh" - add a cron and run it as frequently as you like. 20 mins are optimal.
This script checks system time and invodes backup,sh or rotate.sh jobs. Also it tracks backup status for each server.

* "backup.sh" - it is usually run during off-peak night hours. It looks
for changes in your server since the last backup and rsync's them. This
is where the magic happens - it rsync's only the files which were
modified since the last backup. I have ran it on a busy shared hosting
server with ~5 million inodes 15k SAS -> 7.2K SATA and it took about 5
minutes.

* "rotate.sh" - it creates hard links to save disk space. You
see a complete tree of files in each date. It removes old files to match
a set number of "daily", "weekly" and "monthly" backups. As an extra You
can easily configure it to gzip large and always changing files (I'm
looking at you, large databases and logs). And the most important aspect
- it runs during the daytime, when the backup servers are idle!

* "filelist-generator.sh" - finds all files changed since last backup on a remote mashine

Why this is faster than regular "rsync"?

While sync'ing "SOURCE:/source_file" to "DESTINATION:/destination_file"
rsync compares "ctime" and size on both hosts. This means high amount of
read IOPS on SATA. BUilding a list of files saves you large chunk of 
recursion influenced I/O.

There is also a set of neat options like full "rsync" parameter
customization, excludes, includes, rotation day setup and more. It was
done with many precautions in mind, to keep Your backups consistent and
ready.

I AM NOT RESPONSIBLE FOR ANY DAMAGE, DIRECT OR INDIRECT, THESE BACKUP
SCRIPTS MAY CAUSE YOU. USE AT YOUR OWN RISK!

Legal stuff aside - scripts have friendly comments, are small and easily
readable. Have fun!
