#!/usr/bin/env bash

# Source and Destination of Rsync
RSYNCSOURCE=<rsync host, for example: rsync://mirrors.ocf.berkeley.edu/centos/>
BASEDIR=<Path to mirror directory, example: /srv/mirror/centos>

# use host name in Lockfile name, credit to Debian's ftpsync tool for the idea,
# as they do the same thing
MIRRORNAME=$(hostname -f)
LOCK="${BASEDIR}/Archive-Update-in-Progress-${MIRRORNAME}"

# variables for logging
DAY=$(date | tr -s ' ' | tr ' ' '-' | cut -d '-' -f2,3,4)
FILENAME=centos-rsync-$DAY.log
LOGPATH=/<path to log directory>/centos/$FILENAME

# set rsync bandwidth in KB, 0 means unlimited
RSYNC_BW=0

# sync is already running, important for initial sync or if there's a massive update,
# or if you're syncing very often and a sync is larger than normal, the one exception is
# when we are running the script and it is already running, i.e, the lockfile exists.
# We should leave it alone and gracefully exit then
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
#	echo "Updates via rsync already running. $DAY" > "$LOGPATH"
	exit 5
fi

if [ -d ${BASEDIR} ] ; then
	echo "Lockfile set for $DAY mirror update" > "$LOGPATH"
	touch ${LOCK}
	echo "Beginning stage 1 sync" >> "$LOGPATH"
	# First Time Sync
	# rsync  -avSHP --stats --safe-links --exclude "local" --exclude "isos" ${RSYNCSOURCE} ${BASEDIR}
	# cron
	rsync  -avSHP --stats --safe-links --exclude "local" --exclude "isos" --bwlimit=${RSYNC_BW} ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
	STAGEONECODE=$?
	if (( STAGEONECODE != 0 ))
	then
		NAPTIME=$(( RANDOM % 6 + 6 ))
		echo "Stage 1 sync failed on first attempt, sleeping for $NAPTIME minutes and entering loop" >> "$LOGPATH"
		sleep $(( NAPTIME ))m
		n=1
		until [ $n -ge 10 ]
		do
			# First Time Sync
			# rsync  -avSHP --stats --safe-links --exclude "local" --exclude "isos" ${RSYNCSOURCE} ${BASEDIR}
			# cron
			rsync  -avSHP --stats --safe-links --exclude "local" --exclude "isos" --bwlimit=${RSYNC_BW} ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
			STAGEONECODE=$?
			if (( STAGEONECODE == 0 ))
			then
				echo "Stage 1 sync finished after $n retries." >> "$LOGPATH"
				break
			else
				NAPTIME=$(( RANDOM % 6 + 6 ))
				echo "Stage 1 sync failed, sleeping for $NAPTIME minutes" >> "$LOGPATH"
				sleep $(( NAPTIME ))m
			fi
			n=$(($n+1))
		done
		if (( STAGEONECODE != 0 ))
		then
			echo "Stage 1 Failed after $n retries." >> "$LOGPATH"
			exit 1
		fi
	fi
	{
		echo "Stage 1 sync Finished Successfully" >> "$LOGPATH"
		echo "Running stage 2 sync"
	} >> "$LOGPATH"

	# First Time Sync
	# rsync  -avSHP --stats --delete --delete-after --delay-updates ${RSYNCSOURCE} ${BASEDIR}
	# cron
	rsync  -avSHP --stats --safe-links --bwlimit=${RSYNC_BW} --delete --delete-after --delay-updates ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
	STAGETWOCODE=$?

	if (( STAGETWOCODE != 0 ))
	then
		NAPTIME=$(( RANDOM % 6 + 6 ))
		echo "Stage 2 failed on first try, sleeping for $NAPTIME minutes and entering loop" >> "$LOGPATH"
		sleep $(( NAPTIME ))m
		n=1
		until [ $n -ge 10 ]
		do
			# First Time Sync
			# rsync  -avSHP --stats --delete --delete-after --delay-updates ${RSYNCSOURCE} ${BASEDIR}
			# cron
			rsync  -avSHP --stats --safe-links --bwlimit=${RSYNC_BW} --delete --delete-after --delay-updates ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
			STAGETWOCODE=$?
			if (( STAGETWOCODE == 0 ))
			then
				echo "Stage 2 finished after $n retries" >> "$LOGPATH"
				break
			else
				NAPTIME=$(( RANDOM % 6 + 6 ))
				echo "Stage 2 failed, sleeping for $NAPTIME minutes" >> "$LOGPATH"
				sleep $(( NAPTIME ))m
			fi
			n=$(($n+1))
		done
		if (( STAGETWOCODE != 0 ))
		then
			echo "Stage 2 Failed after $n retries." >> "$LOGPATH"
			exit 1
		fi
	fi
	echo "Stage 2 Finished Successfully" >> "$LOGPATH"
	/bin/rm -f ${LOCK}
	echo "Sync lockfile removed" >> "$LOGPATH"
else
	echo "Target directory $BASEDIR not present." >> "$LOGPATH"
fi

