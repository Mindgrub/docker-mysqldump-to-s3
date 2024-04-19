#!/bin/sh
set -e
set -o pipefail

# Send heartbeat
if [ -n "$SFN_TASK_TOKEN" ]; then
  aws stepfunctions send-task-heartbeat --task-token "$SFN_TASK_TOKEN"
fi

# Variable defaults
: "${FILENAME_PREFIX:=snapshot}"
: "${S3_STORAGE_TIER:=STANDARD_IA}"
: "${DB_PORT:=3306}"

# Set up our output filenames
timestamp=$(date --iso-8601=seconds | tr -d ':-' | cut -c1-15)
filename="${FILENAME_PREFIX}-${timestamp}.sql.gz"
destination="/data/$filename"
s3_url="s3://${S3_BUCKET}/${S3_PREFIX}${filename}"

# Export the database
set -- -h "$DB_HOST" -u "$DB_USER" --password="$DB_PASS" -P "$DB_PORT" -R -E --triggers --single-transaction --comments
if [ -n "$MYSQL_NET_BUFFER_LENGTH" ]; then
  set -- "$@" --net-buffer-length="$MYSQL_NET_BUFFER_LENGTH"
fi
if [ -n "$MYSQLDUMP_OPTS" ]; then
  set -- "$@" $MYSQLDUMP_OPTS
fi
set -- "$@" "$DB_NAME"
mysqldump_opts=$(printf ' %s' "$@")
echo "About to export mysql://$DB_HOST/$DB_NAME to $destination"
eval "mysqldump $mysqldump_opts" | gzip > "$destination"
echo "Export to $destination completed"

# Send heartbeat
if [ -n "$SFN_TASK_TOKEN" ]; then
  aws stepfunctions send-task-heartbeat --task-token "$SFN_TASK_TOKEN"
fi

# Publish to S3
extra_metadata=""
if [ -n "$REQUESTOR" ]; then
    extra_metadata=",Requestor=$REQUESTOR"
fi
echo "About to upload $destination to $s3_url"
aws s3 cp "$destination" "$s3_url" --storage-class "$S3_STORAGE_TIER" --metadata "DatabaseHost=${DB_HOST},DatabaseName=${DB_NAME}${extra_metadata}"
echo "Upload to $s3_url completed"

# Send activity success
if [ -n "$SFN_TASK_TOKEN" ]; then
  json_output=$(jq -cn --arg uri "$s3_url" '{"uri":$uri}')
  aws stepfunctions send-task-success --task-token "$SFN_TASK_TOKEN" --task-output "$json_output"
fi
