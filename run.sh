#!/bin/sh
set -exo pipefail

# Variable defaults
: "${FILENAME_PREFIX:=snapshot}"
: "${MYSQL_NET_BUFFER_LENGTH:=16384}"
: "${S3_STORAGE_TIER:=STANDARD_IA}"

# Set up our output filename
timestamp=$(date --iso-8601=seconds | tr -d ':-' | cut -c1-15)
filename="${FILENAME_PREFIX}-${timestamp}.sql.gz"
destination="/data/$filename"

# Export the database
mysqldump -h "$DB_HOST" -u "$DB_USER" --password="$DB_PASS" -R -E --triggers --single-transaction --comments --set-gtid-purged=off --column-statistics=0 --net-buffer-length="$MYSQL_NET_BUFFER_LENGTH" "$DB_NAME" | gzip > "$destination"

extra_metadata=""
if [[ ! -z "$REQUESTOR" ]]; then
    extra_metadata=",Requestor=$REQUESTOR"
fi

# Publish to S3
aws s3 cp "$destination" "s3://${S3_BUCKET}/${S3_PREFIX}${filename}" --storage-class "$S3_STORAGE_TIER" --metadata "DatabaseHost=${DB_HOST},DatabaseName=${DB_NAME}${extra_metadata}"
