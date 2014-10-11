LitBackup is a rock simple backup solution with a few unique features.

Main advantages:
* blazingly fast - 5 million files in under 5 minutes (depending on configuration)
* load balancing - backup jobs and maintenance are running separately. You tell when.
* easy on disks - large disks are slow, it uses them wisely
* very intuitive - all backups are folders with dates
* adaptive - just a few configuration options to change. Other options are there if You
need them.
* simple - written in BASH, requires "rsync" and "find"
* totally FREE - released under GPL v3


LitBackup mainly consists of two scripts:

* "backup.sh" - it is usually run during off-peak night hours. It looks
for changes in your server since the last backup and rsync's them. This
is where the magic happens - it rsync's only the files which were
modified since the last backup. I have ran it on a busy shared hosting
server with ~5 million inodes 15k SAS -> 7.2K SATA and it took about 5
minutes. Talk about speed!


* "rotate-backups.sh" - it creates hard links to save disk space. You
see a complete tree of files in each date. It removes old files to match
a set number of "daily", "weekly" and "monthly" backups. As an extra You
can easily configure it to gzip large and always changing files (I'm
looking at you, large databases and logs). And the most important aspect
- it runs during the daytime, when the backup servers are idle!

Everyone asks: why this is faster than regular "rsync"?

When rsync syncs two directories "/source" and "/destination" on hosts "srchost" and "dsthost", it compares "ctime" and size on both hosts. It means that on "dsthost" each file generates an "fstat" syscall, which accesses disks. 

My approach is to "find" all files on "srchost" and do only write operations to "dsthost" saving tons of read operations on "dsthost".

Example: imagine that on "srchost" only "/var/log/messages" has changed. If I want to backup "/" I will basically compare whole "srchost" with "dsthost" server for changes and copy only "/var/log/messages". In my case "dsthost" would get a list of files to backup and do just one I/O operation - rsync "/var/log/messages"


There is also a set of neat options like full "rsync" parameter
customization, excludes, includes, rotation day setup and more. It was
done with many precautions in mind, to keep Your backups consistent and
ready.

Although I am considering it almost production-ready, the standart
disclaimer applies:

I AM NOT RESPONSIBLE FOR ANY DAMAGE, DIRECT OR INDIRECT, THESE BACKUP
SCRIPTS MAY CAUSE YOU. USE AT YOUR OWN RISK!

Legal stuff aside - scripts have friendly comments, are small and easily
readable. I am very motivated to improve it and any suggestions and
feature requests are very appreciated:

feedback@litbackup.eu