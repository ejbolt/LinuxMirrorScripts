#!/usr/bin/env bash

#distro path name (i.e. debian-cd or ubuntu-releases) and official name (Debian, Ubuntu, etc)
DISTRO=#"distro"
DISTRONAME=#"official distro name"

# Source and Destination of Rsync
RSYNCSOURCE=#"rsync url::${DISTRO}"
# base directory for ISOs
BASEDIR="/var/www/html/${DISTRO}"

# use host name in Lockfile name, credit to Debian's ftpsync tool for the idea,
# as they do the same thing
MIRRORNAME=$(hostname -f)
LOCK="${BASEDIR}/Archive-Update-in-Progress-${MIRRORNAME}"

# variables for logging, if you want the script to just print to the screen, you can set LOGPATH="/dev/stdout"
DAY=$(date | tr -s ' ' | tr ' ' '-' | cut -d '-' -f2,3,4)
FILENAME="${DISTRO}-rsync-$DAY.log"
LOGPATH="/home/${USER}/log/${DISTRO}/$FILENAME"

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
        echo "Running ${DISTRONAME} CD sync" >> "$LOGPATH"
        rsync -amvSHP --times --links --hard-links --bwlimit=${RSYNC_BW} --block-size=8192 --include="*/" --include="*.iso" --exclude="*" ${RSYNCSOURCE} ${BASEDIR} >> "$LOGPATH"
        SYNCCODE=$?
        # save the exit code from rsync and check for errors (!= 0)
        if (( SYNCCODE != 0 ))
        then
                NAPTIME=$(( RANDOM % 6 + 6 ))
                echo "First CD sync attempt failed, sleeping for $NAPTIME minutes and trying again" >> "$LOGPATH"
                sleep $(( NAPTIME ))m
                n=1 # keep track of how many failures we've had
                until [ $n -ge 10 ]
                do
                        rsync -amvSHP --times --links --hard-links --bwlimit=${RSYNC_BW} --block-size=8192 include="*/" --include="*.iso" --exclude="*" ${RSYNCSOURCE} ${BASEDIR}
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
                        echo "Sync lockfile removed; Stage 2 Failed after $n retries." >> "$LOGPATH"
                        /bin/rm -f ${LOCK}
                        exit 1
                fi
        fi
        echo "Sync Finished Successfully" >> "$LOGPATH"
        /bin/rm -f ${LOCK}
        echo "Sync lockfile removed, sync successful" >> "$LOGPATH"
else
        echo "Target directory /var/www/html/${DISTRO} not present."
fi
