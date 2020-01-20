# mongo_db
Scripts for Mongo DB

# This script is for my personal use. If anyone copy and use it, it's not my problem in any case of harm caused by it.


#
# By: Moisa Cardoso (moisescardoso83@gmail.com)
#
# version: 2
# *     Modified output messages
# *     Removed function to set initial static parameters
# *     Added Lock file and trap (with function)
# *     Added parameters for DB info
# *     Added query to avoid empty "ns" and avoid "system collections" references
# *     Added function to deleted empty bson files. See below
# *     |-> In case of no transactions, will be created a empty bson file, which will be deleted.
# *     |-> This is to avoid creating a lot of empty files.
#
# version: 3 (Future)
# *     Modify command to create gzipped files 



# This script takes dumps from MongoDB and it's meant to be incremental and run on Replicasets.
#
# To do it, it will:
#
# 1) Create a initial dump using operation logs
# 2) Check last backup, find last oplog timestamp and dump newer info until execution date.
# 

