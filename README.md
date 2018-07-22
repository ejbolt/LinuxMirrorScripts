# LinuxMirrorScripts
Scripts used for creating and maintaining Linux mirrors.

Some distros, like CentOS and Ubuntu have their own scripts, and these scripts are tested and work well.  They are based on example rsync commands given by the organizations that own the distros, and improved upon during the creation of mirrors for a university.  They also drew inspiration from the 'ftpsync' tool used by the folks at Debian, which is very robust.  I highly recommend looking at it.  It's a 800-ish line bash script, so can be a bit daunting, but it is a very powerful tool.

A generic script is also provided with any distro names removed.  It should only require you to set variables to the correct values in the scripts.  However, you should consult the proper distro's wiki on how to properly mirror them if you intend to become an official mirror.  Some distros use different rsync options, and some do multiple stages of rsync to prevent issues for any users trying to update their system while the mirror is syncing changes.

I've also provided scripts for mirroring ISO files too.  Those are fairly straightforward.  CentOS's ISOs are included in the mirrors, so there is only one script for CentOS.

All these scripts use very similar variables to ftpsync, as I found them to be clear names, and for sake of familiarity for anyone who's used ftpsync.

NOTE: For Debian-based distributions you should look into using 'ftpsync', the recommended tool for mirroring Debian and its derivatives.  However, Ubuntu was the exception.  ftpsync looks for certain files and when I ran it on Ubuntu mirrors, those files did not exist.  This may be due to a misunderstanding of mine on how the tool works, or the mirror was not created with ftpsync and so does not have the appropriate files or have them in the proper format.

And as always, feel free to let me know how to improve on the script!  Current todo list stands at:

1. Implement config files to make scripts cleaner and easier to configure.
2. Use variables as much as possible to make more configurable.
2. Better format for logging.
3. Look into any missing/better flags to use for rsync.
