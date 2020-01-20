#!/bin/bash

function initStaticParams
{
   CONN_STRING="mongodb://USER:abc123@ADDRESS:PORT/DBNAME?replicaSet=REPLICASET_NAME&authSource=admin"
   OUTPUT_DIRECTORY=PATH_TO_BACKUP
   LOG_FILE="PATH/TO/LOG/FILE.log"
   LOG_MESSAGE_ERROR=1
   LOG_MESSAGE_WARN=2
   LOG_MESSAGE_INFO=3
   LOG_MESSAGE_DEBUG=4
   LOG_LEVEL=$LOG_MESSAGE_DEBUG
   SCRIPT=`readlink -f ${BASH_SOURCE[0]}`
   ABSOLUTE_SCRIPT_PATH=$(cd `dirname "$SCRIPT"` && pwd)
}

INFO="\e[32mINFO\e[0m"
ERROR="\e[31mERROR\e[0m"
WARN="\e[93mWARN\e[0m"
DEBUG="\e[$DEBUG\e[0m"

function log
{
   MESSAGE_LEVEL=$1
   shift
   MESSAGE="$@"

   if [ $MESSAGE_LEVEL -le $LOG_LEVEL ]; then
      echo -e "`date +'%Y-%m-%dT%H:%M:%S.%3N'` $MESSAGE" >> $LOG_FILE
   fi
}

initStaticParams

log $LOG_MESSAGE_INFO "[$INFO] Starting incremental Backup of Oplog"

mkdir -p $OUTPUT_DIRECTORY

LAST_OPLOG_DUMP=`ls -t ${OUTPUT_DIRECTORY}/*.bson  2> /dev/null | head -1`

if [ "$LAST_OPLOG_DUMP" != "" ]; then
   log $LOG_MESSAGE_DEBUG "[$DEBUG] Last incremental Oplog backup is: \e[32m$LAST_OPLOG_DUMP\e[0m"
   LAST_OPLOG_ENTRY=`bsondump ${LAST_OPLOG_DUMP} 2>> $LOG_FILE | grep ts | tail -1`
   if [ "$LAST_OPLOG_ENTRY" == "" ]; then
      log $LOG_MESSAGE_ERROR "[$ERROR] Evaluating last Oplog backup entry with bsondump \e[31mfailed\e[0m"
      exit 1
   else
        TIMESTAMP_LAST_OPLOG_ENTRY=`echo $LAST_OPLOG_ENTRY | jq '.ts[].t'`
        INC_NUMBER_LAST_OPLOG_ENTRY=`echo $LAST_OPLOG_ENTRY | jq '.ts[].i'`
#       START_TIMESTAMP="Timestamp( ${TIMESTAMP_LAST_OPLOG_ENTRY}, ${INC_NUMBER_LAST_OPLOG_ENTRY} )"
        START_TIMESTAMP='{"ts":{"$gt":{ "t":${TIMESTAMP_LAST_OPLOG_ENTRY},"i":${INC_NUMBER_LAST_OPLOG_ENTRY}}}}'
     log $LOG_MESSAGE_DEBUG "[$DEBUG] Dumping everything newer than $START_TIMESTAMP"
   fi
   log $LOG_MESSAGE_DEBUG "[$DEBUG] Last Oplog backup entry: $LAST_OPLOG_ENTRY"
else
   log $LOG_MESSAGE_WARN "[$WARN] No Oplog backup available. \e[93mCreating initial backup\e[0m "
fi

if [ "$LAST_OPLOG_ENTRY" != "" ]; then
   mongodump --uri "${CONN_STRING}" -c oplog.rs --query "{\"ts\":{ \"\$gt\"  :{ \"\$timestamp\":{\"t\":"$TIMESTAMP_LAST_OPLOG_ENTRY",\"i\":"$INC_NUMBER_LAST_OPLOG_ENTRY"}}}}" -o - >${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson 2>> $LOG_FILE
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

if [ $FILESIZE -eq 0 ]; then
   log $LOG_MESSAGE_WARN "[$WARN] No documents have been dumped with incremental backup (No changes in mongodb since last backup?)."
   log $LOG_MESSAGE_WARN "[$WARN] Deleting ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson"
   rm -f ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson
else
   log $LOG_MESSAGE_INFO "[$INFO] Finished incremental backup of Oplog to: ${OUTPUT_DIRECTORY}/${TIMESTAMP_LAST_OPLOG_ENTRY}_${INC_NUMBER_LAST_OPLOG_ENTRY}_oplog.bson"
fi

echo "###########" >> $LOG_FILE
