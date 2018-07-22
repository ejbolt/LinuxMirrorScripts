#!/usr/bin/env bash

# List of Ubuntu mirrors and their statuses at https://launchpad.net/ubuntu/+archivemirrors
# Source and Destination of Rsync
RSYNCSOURCE=#<rsync host, for example: rsync://ubuntu.cs.utah.edu/ubuntu>
BASEDIR=#<Path to mirror directory, example: /srv/mirror/ubuntu>

# use host name in Lockfile name, credit to Debian's ftpsync tool for the idea,
# as they do the same thing
MIRRORNAME=$(hostname -f)
LOCK="${BASEDIR}/Archive-Update-in-Progress-${MIRRORNAME}"

# variables for logging, if you want the script to just print to the screen, you can set LOGPATH="/dev/stdout"
DAY=$(date | tr -s ' ' | tr ' ' '-' | cut -d '-' -f2,3,4)
FILENAME=ubuntu-rsync-$DAY.log
LOGPATH=#<Path to log directory>/ubuntu/$FILENAME

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
	echo "Updates via rsync already running. $DAY" > "$LOGPATH"
	exit 5
fi

# make sure your target directory exists
if [ -d ${BASEDIR} ]; then
	echo "Lockfile set for $DAY mirror update" > "$LOGPATH"
	touch ${LOCK}
	echo "Beginning stage 1 sync" >> "$LOGPATH"
	#rsync -av --partial --delete --delete-after --bwlimit=${RSYNC_BW} --exclude "indices/" --exclude "dists/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
	rsync -av --recursive --times --links --safe-links --hard-links --stats --progress --bwlimit=${RSYNC_BW} --exclude "indices/" --exclude "dists/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
	STAGEONECODE=$?
	# save the exit code from rsync and check for errors (!= 0)
	if (( STAGEONECODE != 0 ))
	then
		# sleep for 6-12 minutes
		NAPTIME=$(( RANDOM % 6 + 6 ))
		echo "Stage 1 failed on first attempt, sleeping for $NAPTIME minutes and entering loop" >> "$LOGPATH"
		sleep $(( NAPTIME ))m
		n=1	# keep track of how many failures we've had
		until [ $n -ge 10 ]
		do
			#rsync -av --partial --delete --delete-after --bwlimit=${RSYNC_BW} --exclude "indices/" --exclude "dists/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
			rsync -av --recursive --times --links --safe-links --hard-links --stats --progress --bwlimit=${RSYNC_BW} --exclude "indices/" --exclude "dists/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
			STAGEONECODE=$?
			if (( STAGEONECODE == 0 ))
			then
				echo "Stage 1 finished after $n retries" >> "$LOGPATH"
				break
			else
				NAPTIME=$(( RANDOM % 6 + 6 ))
				echo "Stage 1 failed, sleeping for $NAPTIME minutes" >> "$LOGPATH"
				sleep $(( NAPTIME ))m
			fi
			n=$(($n+1))
		done
		# quit after 10 times, if it still failed, report the number of failures (always 10 at this point), and exit
		if (( STAGEONECODE != 0 ))
		then
			echo "Stage 1 Failed after $n retries." >> "$LOGPATH"
			exit 1
		fi
	fi
	# Report that first stage of the sync is done
	{
		echo "Stage 1 Finished Successfully"
		echo "Running stage 2 sync"
	} >> "$LOGPATH"

	# do stage 2 sync, this includes deleting files, this is done to prevent deletion while someone is downloading from the mirror during a mirror update

	# rsync -av --partial --delete --delete-after --bwlimit=${RSYNC_BW} --exclude "pool/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
	rsync -av --recursive --times --links --safe-links --hard-links --stats --progress --bwlimit=${RSYNC_BW} --exclude "pool/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" --delete --delete-after ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
	STAGETWOCODE=$?
	# save rsync error code
	if (( STAGETWOCODE != 0 ))
	then
		NAPTIME=$(( RANDOM % 6 + 6 ))
		echo "Stage 2 failed on first try, sleeping for $NAPTIME minutes and entering loop" >> "$LOGPATH"
		sleep $(( NAPTIME ))m
		n=1
		until [ $n -ge 10 ]
		do
			# rsync -av --partial --delete --delete-after --bwlimit=${RSYNC_BW} --exclude "pool/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
			rsync -av --recursive --times --links --safe-links --hard-links --stats --progress --bwlimit=${RSYNC_BW} --exclude "pool/" --exclude "project/trace/${MIRRORNAME}" --exclude "Archive-Update-in-Progress-${MIRRORNAME}" --delete --delete-after ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
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

	date -u > ${BASEDIR}/project/trace/$(hostname -f)
else
	echo "Target directory $BASEDIR not present." >> "$LOGPATH"
fi

