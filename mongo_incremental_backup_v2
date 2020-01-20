#!/bin/bash
#
# By: Moisa Cardoso (moisescardoso82@gmail.com)
#
# version: 2
# *     Removed function to set initial statci params
# *     Added Lck file and trap
# *     Added possibility to pass db and server info via params
#
# *     Added query to avoid empty ns and avoid system collections references
# *     Added function to deleted empty bson files. See below
# *     |-> In case of no transactions, will be created a empty bson file, which will be deleted.
# *     |-> This is to avoid creating a lot of empty files.


# This script takes dumps from MongoDB and it's meant to be incremental and run on Replicasets.
#
# To do it, it will:
#
# 1) Create a initial dump from mongo internal "local"(oplog.rs) database (
# which is a local mirror of other databases and have all operations timestamped.
# Using this operation timestamp, we're able to walk through all info that mongo has ever
# handled)
#
# 2) Check last backup, find last oplog timestamp and dump newer info until execution date.
#

if [ $# -gt 0 -a $# -lt 4 ]; then
    echo -e "\nUsage: $0 [ USER PASSWORD DATABASE_NAME SERVERS ]\nThis script may run with all OPTIONS or NONE.\n
If you're passing a replicaSet destination, as the fourth parameter, quote it with double-quotes (\"server1:port,server2:port,server3:port\")"
    exit 3
fi

trap unlock SIGINT SIGKILL SIGKILL

USER=${1:-PUT_A_USERNAME_HERE}
PASSWORD=${2:-PUT_A_PASSWORD_HERE}
DATABASE=${3:-PUT_A_DB_HERE}
DESTINATION=${4:-SERVER_ADDRESS:PORT}
CONN_STRING="mongodb://${USER}:${PASSWORD}@${DESTINATION}/${DATABASE}?replicaSet=REPLICASET_NAME&authSource=admin"
OUTPUT_DIRECTORY="OUTPUT/DIRECTORY/PATH"
LOG_FILE="/LOGS/PATH/LOG.log"
LOCK_FILE="/PATH/TO/MONGO.LOCK"
LOG_MESSAGE_ERROR=1
LOG_MESSAGE_WARN=2
LOG_MESSAGE_INFO=3
LOG_MESSAGE_DEBUG=4
LOG_LEVEL=$LOG_MESSAGE_DEBUG
SCRIPT=`readlink -f ${BASH_SOURCE[0]}`
ABSOLUTE_SCRIPT_PATH=$(cd `dirname "$SCRIPT"` && pwd)
 INFO="\e[32mINFO\e[0m"
ERROR="\e[31mERROR\e[0m"
 WARN="\e[93mWARN\e[0m"
DEBUG="\e[93mDEBUG\e[0m"

# Check PID lock
if [ -r "$LOCK_FILE" ]; then
    echo "Script is already running. Exiting."
    exit 2
else
    touch "$LOCK_FILE" &>/dev/null
fi

function unlock()
{
        rm -f ${LOCK_FILE} 2>/dev/null
}

function log
{
    MESSAGE_LEVEL=$1
    shift
    MESSAGE="$@"

    if [ $MESSAGE_LEVEL -le $LOG_LEVEL ]; then
       echo -e "`date +'%Y-%m-%dT%H:%M:%S.%3N'` $MESSAGE" >> $LOG_FILE
    fi
}

mkdir -p $OUTPUT_DIRECTORY 2>/dev/null

LAST_OPLOG_DUMP=`ls -t ${OUTPUT_DIRECTORY}/*.bson  2> /dev/null | head -1`

if [ "$LAST_OPLOG_DUMP" != "" ]; then
  log $LOG_MESSAGE_DEBUG "[$INFO]  Found a backup file: \e[32;4m$LAST_OPLOG_DUMP\e[0m"

  # Check last timestamp on last dump file.
  log $LOG_MESSAGE_DEBUG "[$INFO]  Traversing \e[32;4m$LAST_OPLOG_DUMP\e[0m to find last timestamp. "
  LAST_OPLOG_ENTRY=`bsondump ${LAST_OPLOG_DUMP} 2>/dev/null | grep -w "\"ts\":" | tail -1`

    if [ "$LAST_OPLOG_ENTRY" == "" ]; then
        log $LOG_MESSAGE_ERROR "[$ERROR] Evaluating last Oplog backup entry with bsondump \e[31mFAILED\e[0m"
        unlock
        exit 1
    else
        TIMESTAMP_LAST_OPLOG_ENTRY=`echo $LAST_OPLOG_ENTRY | jq '.ts[].t'`
        INC_NUMBER_LAST_OPLOG_ENTRY=`echo $LAST_OPLOG_ENTRY | jq '.ts[].i'`
        # Remember that: "Starting in MongoDB 4.2, the query must be in Extended JSON v2 format
        # (either relaxed or canonical/strict mode), including enclosing the field names and operators in quotes."
       log $LOG_MESSAGE_DEBUG "[$DEBUG] Dumping everything newer than \"[$(date --date="@${TIMESTAMP_LAST_OPLOG_ENTRY}" +'%Y-%m-%d %H:%M:%S')]\""
    fi

else
    log $LOG_MESSAGE_WARN "[$WARN] No Oplog backup file available. \e[93;3mCreating initial backup\e[0m "
fi

if [ "$LAST_OPLOG_ENTRY" != "" ]; then
        #Added on 2.5
        mongodump --uri="${CONN_STRING}" \
        -c oplog.rs \
        --query "{\"\$and\": [{\"ts\":{ \"\$gt\" :{ \"\$timestamp\":\
                 {\"t\":$TIMESTAMP_LAST_OPLOG_ENTRY,\"i\":$INC_NUMBER_LAST_OPLOG_ENTRY}}}},
                 {\"ns\": {\"\$nin\": [\"\", \"config.system.sessions\", \"config.transactions\",
                 \"config.transaction_coordinators\", \"admin.system.users\",\"admin.system.keys\",
                 \"admin.system.roles\",\"admin.system.version\"]}}]}" -o - \
        > ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson 2>>${LOG_FILE}
        RET_CODE=$?
else
        TIMESTAMP_LAST_OPLOG_ENTRY=0000000000
        INC_NUMBER_LAST_OPLOG_ENTRY=0
        mongodump --uri "${CONN_STRING}" -c oplog.rs -o - >${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson 2>> $LOG_FILE
    RET_CODE=$?
fi

if [ $RET_CODE -gt 0 ]; then
    log $LOG_MESSAGE_ERROR "[$ERROR] Incremental backup of oplog with mongodump failed with return code \e[93m$RET_CODE\[0m"
fi

FILESIZE=`stat --printf="%s" ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson`

if [ ${FILESIZE:-0} -eq 0 ]; then
    log $LOG_MESSAGE_WARN "[$WARN] No documents have been dumped with incremental backup (No changes since last backup?)."
    log $LOG_MESSAGE_WARN "[$WARN] Deleting ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson"
    rm -f ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson
else
    log $LOG_MESSAGE_INFO "[$INFO]  Finished incremental backup of Oplog to: ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson"
fi

echo "###########" >> $LOG_FILE
rm -f ${LOCK_FILE} 2>/dev/null
