#!/bin/bash

function usage() {
  echo "To dump to folder:"
  echo "dump_database -h [host] -u [user] -p [password] -d [destination folder]"
  echo "dump_database --host [host] --user [user] --pass [password] --dest [destination folder]"
  echo "To dump to bucket:"
  echo "dump_database -h [host] -u [user] -p [password] -b [bucket name]"
  echo "dump_database --host [host] --user [user] --pass [password] --bucket [bucket name]"
  exit 1
}

HOST=
USER=
PORT=
DEST=

while [ "$1" != "" ]; do
  case $1 in
    -h | --host )           shift
                            HOST="$1"
                            ;;
    -u | --user )           shift
                            USER="$1"
                            ;;
    -p | --pass )           shift
                            PASS="$1"
                            ;;
    -d | --dest )            shift
                            DEST="$1"
                            ;;
    -b | --bucket )          shift
                            BUCKET="$1"
                            ;;
    -e | --endpoint )          shift
                            ENDPOINT="$1"
                            ;;
    -P | --port )            shift
                            PORT="$1"
                            ;;
    --help )           usage
                            exit
                            ;;
    * )                     usage
                            exit 1
  esac
  shift
done

TARGET_PREFIX=$DEST/$(date +%Y-%m)/$(date +%F)
TARGET_BUCKET_PREFIX=$(date +%Y-%m)/$(date +%F)
DATE_PREFIX=$(date +%F:%H:%M)

#BEHIND=60
#until (( $BEHIND < 10 ));
#do
#  BEHIND=$(echo "SHOW SLAVE STATUS\G" | /usr/bin/mysql -h$HOST -P$PORT -u$USER -p$PASS)
#  if (( $BEHIND >10 )); then
#    echo Replication lag, waiting for server to catch up
#    sleep 3
#  fi
#done

DB_LIST=$(mariadb -h$HOST -P$PORT -u$USER -p$PASS -B -N -e 'SHOW DATABASES' | egrep -v '^mysql$|^innodb$|^information_schema$|^performance_schema$' | tr '\n' ' ')
DB_LIST_COMMA=$(echo ${DB_LIST} | tr '[:space:]' , | sed -e 's/,$//g')

#echo 'pre stop status'
#mysql -h$HOST -P$PORT -u$USER -p$PASS -B -N -e 'SHOW SLAVE STATUS\G'

#mysql -h$HOST -P$PORT -u$USER -p$PASS -B -N -e 'CALL mysql.rds_stop_replication;'

if [[ -z "$BUCKET" && -z "$ENDPOINT" ]]
then
  echo "dumping to disk"
  for DB_NAME in ${DB_LIST}
  do
    mkdir -p "$TARGET_PREFIX"
    FILENAME=$TARGET_PREFIX/$DATE_PREFIX-$DB_NAME.sql.gz
    mariadb-dump --max_allowed_packet=1G --opt \
      -u$USER -p$PASS -h$HOST -P$PORT \
       --master-data=2 \
      --databases $DB_NAME \
      | pigz > /backups/$FILENAME \
      || 
  done
elif [ -z "$ENDPOINT" ]
then
  echo "uploading to aws s3"
  for DB_NAME in ${DB_LIST}
  do
    FILENAME=$TARGET_BUCKET_PREFIX/$DATE_PREFIX-$DB_NAME.sql.gz
    mariadb-dump --max_allowed_packet=1G --opt \
      -u$USER -p$PASS -h$HOST -P$PORT \
       --master-data=2 \
      --databases $DB_NAME \
      | pigz | aws s3 cp - s3://$BUCKET/$FILENAME \
      || 
  done  
else
  echo "uploading to custom s3"
  for DB_NAME in ${DB_LIST}
  do
    FILENAME=$TARGET_BUCKET_PREFIX/$DATE_PREFIX-$DB_NAME.sql.gz
    mariadb-dump --max_allowed_packet=1G --opt \
      -u$USER -p$PASS -h$HOST -P$PORT \
       --master-data=2 \
      --databases $DB_NAME \
      | pigz | aws --endpoint $ENDPOINT s3 cp - s3://$BUCKET/$FILENAME \
      || 
  done
fi

#mysql -h$HOST -P$PORT -u$USER -p$PASS -B -N -e 'CALL mysql.rds_start_replication;'
#echo 'post start status'
#mysql -h$HOST -P$PORT -u$USER -p$PASS -B -N -e 'SHOW SLAVE STATUS\G'
