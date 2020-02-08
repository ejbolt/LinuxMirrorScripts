#!/usr/bin/env bash

set -E

DISTRO=
CONFIGFILE="${DISTRO}-rsync.conf"

HOMEDIR=$(cat /etc/passwd | grep $(whoami) | cut -d ':' -f6)

. "${HOMEDIR}/${DISTRO}/${CONFIGFILE}"

# sync is already running, important for initial sync or if there's a massive update,
# or if you're syncing very often and a sync is larger than normal, the one exception is
# when we are running the script and it is already running, i.e, the lockfile exists.
# We should leave it alone and gracefully exit then
function cleanup
{
    if [ $? -ne 5 ]
    then
        rm "${LOCK}"
    fi
}
exec 99>"${LOCK}" || exit 5
flock -x -n 99 || (echo "Updates via rsync are already running. ${DAY}" >> "${LOGPATH}"; exit 5)

# Note: files/dirs to exclude are dependent on distro flavors.  Debian-based are similar, RedHat based are similar.  Look in to the distro when choosing
# recommended files to exclude in 1st stage
STAGEONE_EXCLUDE_LIST=( "${LOCKFILE}" )
# can modify if statement to apply to debian and its derivatives but you SHOULD use ftpsync if possible for Debian
if [[ "${DISTRO}" == "ubuntu" ]]
then
	STAGEONE_EXCLUDE_LIST=( "indices/" "dists/" "project/trace/${MIRRORNAME}" "${LOCKFILE}" )
else
	STAGEONE_EXCLUDE_LIST=( "${LOCKFILE}" )
fi
STAGEONE_EXCLUDE=""

# recommended files to exclude in 2nd stage
# can modify if statement to apply to debian and its derivatives but you SHOULD use ftpsync if possible for Debian
if [[ "${DISTRO}" == "ubuntu" ]]
then
	STAGETWO_EXCLUDE_LIST=( "pool/" "project/trace/${MIRRORNAME}" "${LOCKFILE}" )
else
	STAGETWO_EXCLUDE_LIST=( "${LOCKFILE}" )
fi
STAGETWO_EXCLUDE=""

# loops that generate '--exclude' strings
for i in "${STAGEONE_EXCLUDE_LIST[@]}"
do
	STAGEONE_EXCLUDE+="--exclude $i"
	#ensure nice spacing format
	if [[ "$i" != "${STAGEONE_EXCLUDE_LIST[-1]}" ]]
	then 
		STAGEONE_EXCLUDE+=" "
	fi
done

for i in "${STAGETWO_EXCLUDE_LIST[@]}"
do
	STAGETWO_EXCLUDE+="--exclude $i"
	#ensure nice spacing format
	if [[ "$i" != "${STAGETWO_EXCLUDE_LIST[-1]}" ]]
	then 
		STAGETWO_EXCLUDE+=" "
	fi
done

# make sure your target directory exists
if [ -d ${BASEDIR} ]; then
	echo "Beginning stage 1 sync" >> "${LOGPATH}"
	rsync ${STAGEONE_OPTIONS} ${RSYNC_BW} ${STAGEONE_EXCLUDE} ${RSYNCSOURCE} ${BASEDIR} >> "${LOGPATH}"
	STAGEONECODE=$?
	# save the exit code from rsync and check for errors (!= 0)
	if (( STAGEONECODE != 0 ))
	then
		# sleep for 6-12 minutes
		NAPTIME=$(( RANDOM % 6 + 6 ))
		echo "Stage 1 failed on first attempt, sleeping for $NAPTIME minutes and entering loop" >> "${LOGPATH}"
		sleep $(( NAPTIME ))m
		n=1	# keep track of how many failures we've had
		until [ $n -ge 10 ]
		do
			rsync ${STAGEONE_OPTIONS} ${RSYNC_BW} ${STAGEONE_EXCLUDE} ${RSYNCSOURCE} ${BASEDIR} >> "${LOGPATH}"
			STAGEONECODE=$?
			if (( STAGEONECODE == 0 ))
			then
				echo "Stage 1 finished after $n retries" >> "${LOGPATH}"
				break
			else
				NAPTIME=$(( RANDOM % 6 + 6 ))
				echo "Stage 1 failed, sleeping for $NAPTIME minutes" >> "${LOGPATH}"
				sleep $(( NAPTIME ))m
			fi
			n=$(($n+1))
		done
		# quit after 10 times, if it still failed, report the number of failures (always 10 at this point), and exit
		if (( STAGEONECODE != 0 ))
		then
			echo "Stage 1 Failed after $n retries." >> "${LOGPATH}"
			exit 1
		fi
	fi
	# Report that first stage of the sync is done
	{
		echo "Stage 1 Finished Successfully"
		echo "Running stage 2 sync"
	} >> "${LOGPATH}"

	# do stage 2 sync, this includes deleting files, this is done to prevent deletion while someone is 
	# downloading from the mirror during a mirror update
	rsync ${STAGETWO_OPTIONS} ${RSYNC_BW} ${STAGETWO_EXCLUDE} ${RSYNCSOURCE} ${BASEDIR} >> "${LOGPATH}"
	STAGETWOCODE=$?
	# save rsync error code
	if (( STAGETWOCODE != 0 ))
	then
		NAPTIME=$(( RANDOM % 6 + 6 ))
		echo "Stage 2 failed on first try, sleeping for $NAPTIME minutes and entering loop" >> "${LOGPATH}"
		sleep $(( NAPTIME ))m
		n=1
		until [ $n -ge 10 ]
		do
			rsync ${STAGETWO_OPTIONS} ${RSYNC_BW} ${STAGETWO_EXCLUDE} ${RSYNCSOURCE} ${BASEDIR} >> "${LOGPATH}"
			STAGETWOCODE=$?
			if (( STAGETWOCODE == 0 ))
			then
				echo "Stage 2 finished after $n retries" >> "${LOGPATH}"
				break
			else
				NAPTIME=$(( RANDOM % 6 + 6 ))
				echo "Stage 2 failed, sleeping for $NAPTIME minutes" >> "${LOGPATH}"
				sleep $(( NAPTIME ))m

			fi
			n=$(($n+1))
		done
		if (( STAGETWOCODE != 0 ))
		then
			echo "Stage 2 Failed after $n retries." >> "${LOGPATH}"
			exit 1
		fi
	fi

	echo "Stage 2 Finished Successfully" >> "${LOGPATH}"

	if [[ "${DISTRO}" == "ubuntu" ]]
	then
		date -u > ${BASEDIR}/project/trace/$(hostname -f)
	fi
else
	echo "Target directory ${BASEDIR} not present." >> "${LOGPATH}"
fi
