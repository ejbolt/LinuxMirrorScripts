#!/usr/bin/env bash

# Source and Destination of Rsync
RSYNCSOURCE=#<rsync host, for example: rsync://mirrors.mit.edu/ubuntu-cdimage/>
BASEDIR=#<Path to mirror directory, example: /srv/mirror/ubuntu-cdimage>

# use host name in Lockfile name, credit to Debian's ftpsync tool for the idea,
# as they do the same thing
MIRRORNAME=$(hostname -f)
LOCK="${BASEDIR}/Archive-Update-in-Progress-${MIRRORNAME}"

# variables for logging, if you want the script to just print to the screen, you can set LOGPATH="/dev/stdout"
DAY=$(date | tr -s ' ' | tr ' ' '-' | cut -d '-' -f2,3,4)
FILENAME=ubuntu-cdimage-rsync-$DAY.log
LOGPATH=#<Path to log directory>/ubuntu-cdimage/$FILENAME

# set rsync bandwidth in KB, 0 means unlimited
RSYNC_BW=0

# sync is already running
function cleanup {
	EXITCODE=$?
	if (( $EXITCODE != 5 ))
	then
		rm -f ${LOCK}
		echo "Lockfile removed" >> "$LOGPATH"
		dos2unix ${LOGPATH}
	fi
}
trap cleanup EXIT

if [ -f ${LOCK} ]; then
	echo "Updates via rsync already running. $DAY" > "$LOGPATH"
	exit 5
fi

# make sure your target directory exists
if [ -d ${BASEDIR} ] ; then
	echo "Setting lockfile for $DAY cd update" > "$LOGPATH"
	touch ${LOCK}
	echo "Running Ubuntu CD sync" >> "$LOGPATH"
	rsync -avSHP --times --links --hard-links --bwlimit=1024000 --block-size=8192 ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
	SYNCCODE=$?
	# save the exit code from rsync and check for errors (!= 0)
	if (( SYNCCODE != 0 ))
	then
		# sleep for 6-12 minutes
		NAPTIME=$(( RANDOM % 6 + 6 ))
		echo "First CD sync attempt failed, sleeping for $NAPTIME minutes and trying again" >> "$LOGPATH"
		sleep $(( NAPTIME ))m
		n=1 # keep track of how many failures we've had
		until [ $n -ge 10 ]
		do
			rsync -avSHP --times --links --hard-links --bwlimit=1024000 --block-size=8192 ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
			SYNCCODE=$?
			if (( SYNCCODE == 0 ))
			then
				echo "Sync finished after $n retries" >> "$LOGPATH"
				break
			else
				NAPTIME=$(( RANDOM % 6 + 6 ))
				echo "Sync failed, sleeping for $NAPTIME minutes" >> "$LOGPATH"
				sleep $(( NAPTIME ))m
			fi
			n=$(($n+1))
		done
		# quit after 10 times, if it still failed, report the number of failures (always 10 at this point), and exit
		if (( SYNCCODE != 0 ))
		then
			echo "Sync Failed after $n retries." >> "$LOGPATH"
			exit 1
		fi
	fi
	echo "Sync Finished Successfully" >> "$LOGPATH"
else
	echo "Target directory $BASEDIR not present."
fi

