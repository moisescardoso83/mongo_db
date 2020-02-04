#!/bin/bash

FULL_DUMP_DIRECTORY=$1
OPLOGS_DIRECTORY=$2
OPLOG_LIMIT=$3
MONGODB_USER=${4:-my_user}
MONGODB_PWD=${5:-my_pass}

# put addresses of pods/hosts here
DESTINATION="mongod-0:27017,mongod-1:27017,mongod-2:27017"
CONN_STRING="mongodb://${MONGODB_USER}:${MONGODB_PWD}@${DESTINATION}/?replicaSet=MainRepSet&authSource=admin"

function help_(){
   echo -e "
   \tThis is script restores mongoDB dumps based on oplogs. It needs a oplog path and a full dump path.\n
   \tUsage: \tscript.sh FULL_DUMP_DIRECTORY OPLOGS_DIRECTORY OPLOG_LIMIT [MONGODB_USER] [MONGODB_PWD]
   \t\tOPLOG_LIMIT: The timestamp until you wish to restore (it's a time before the problem.)\n
   \t\tYou can use:
   \t\t\tISO format: \"YYYY-MM-DD HH:MM:SS\" or\t
   \t\t\tUnix Epoch format: \"NNNNNNNNNN\"\n"

   if [ "X$1" != "X"  ] ; then
        echo -e "Check:\e[31m$1\e[0m"
   fi

   exit 1
}


   if [ $# -lt 3 ]; then
      help_ "Not enough parameters."
   fi

   if [ ! -d $FULL_DUMP_DIRECTORY -o ! -d $OPLOGS_DIRECTORY ]; then
      help_ "Check dump or oplog directory"
   fi

function check_TS(){
# Validate timestamp
   DATE=$*
   if [ `grep -E "([0-9]{10})\b"<<<$DATE` ]; then #test for Epoch TS
         OPLOG_LIMIT=$OPLOG_LIMIT
   elif [[ `grep -E "(\b2[0-9]{3}-[0-9]{2}-[0-9]{2}\s[0-9]{2}:[0-9]{2}:[0-9]{2})\b"<<<$DATE` ]]; then
      OPLOG_LIMIT=$(date +%s -d "${OPLOG_LIMIT}")
   else
      help_ "Timestamp not valid."
   fi
}

check_TS $OPLOG_LIMIT

# The dump directory should be in the format: /dir/dir2/dirN/dumpDate_EPOCHTIME
FULL_DUMP_TIMESTAMP=`basename $FULL_DUMP_DIRECTORY | cut -d "_" -f 2`
LAST_OPLOG=""
ALREADY_APPLIED_OPLOG=0

# case oplog being newer than the dump, mongorestore will use a empty dir
mkdir -p /tmp/emptyDirForOpRestore

# Get timestamp from OPLOG filenames.
for FILE in `find ${OPLOGS_DIRECTORY} -type f -name "*.bson.gz"` ; do
   OPLOG_TIMESTAMP=$(basename $FILE | cut -d "_" -f 1)
   if [ $OPLOG_TIMESTAMP -gt $FULL_DUMP_TIMESTAMP ]; then
      if [ $ALREADY_APPLIED_OPLOG -eq 0 ]; then
         ALREADY_APPLIED_OPLOG=1
         echo -e "\e[32m-> Applying oplog $LAST_OPLOG for the first time(LAST_OPLOG)\e[0m"
         mongorestore --uri="${CONN_STRING}" --oplogFile ${LAST_OPLOG} --oplogReplay --dir /tmp/emptyDirForOpRestore --oplogLimit=${OPLOG_LIMIT} --gzip --drop
         echo " "
         echo -e "\e[32m-> Applying oplog $FILE for the first time.(OPLOG)\e[0m"
               mongorestore --uri="${CONN_STRING}" --oplogFile ${FILE} --oplogReplay --dir /tmp/emptyDirForOpRestore --oplogLimit=${OPLOG_LIMIT} --gzip --drop
      else
         echo -e "\e[32m-> Applying oplog ${FILE}(OPLOG)\e[0m"
               mongorestore --uri="${CONN_STRING}" --oplogFile ${FILE} --oplogReplay --dir /tmp/emptyDirForOpRestore --oplogLimit=${OPLOG_LIMIT} --gzip --drop
      fi
   else
      LAST_OPLOG=$FILE
   fi
done

if [ $ALREADY_APPLIED_OPLOG -eq 0 ]; then
   if [ "$LAST_OPLOG" != "" ]; then
      echo -e "\n\e[32m-> Applying oplog ${LAST_OPLOG}(LAST_OPLOG)\e[0m"
      mongorestore --uri="${CONN_STRING}" --oplogFile $LAST_OPLOG --oplogReplay --dir $FULL_DUMP_DIRECTORY --oplogLimit=$OPLOG_LIMIT --gzip --drop
   fi
fi
echo ""
echo -e "\n########################### END OF SCRIPT ###########################"
