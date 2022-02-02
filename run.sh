#!/bin/sh
set -eo pipefail

# Variable defaults
: "${FILENAME_PREFIX:=snapshot}"
: "${MYSQL_NET_BUFFER_LENGTH:=16384}"
: "${S3_STORAGE_TIER:=STANDARD_IA}"

# Set up our output filenames
timestamp=$(date --iso-8601=seconds | tr -d ':-' | cut -c1-15)
filename="${FILENAME_PREFIX}-${timestamp}.sql.gz"
destination="/data/$filename"
s3_url="s3://${S3_BUCKET}/${S3_PREFIX}${filename}"

# Export the database
echo "About to export mysql://$DB_HOST/$DB_NAME to $destination"
mysqldump -h "$DB_HOST" -u "$DB_USER" --password="$DB_PASS" -R -E --triggers --single-transaction --comments --net-buffer-length="$MYSQL_NET_BUFFER_LENGTH" "$DB_NAME" | gzip > "$destination"
echo "Export to $destination completed"

extra_metadata=""
if [[ ! -z "$REQUESTOR" ]]; then
    extra_metadata=",Requestor=$REQUESTOR"
fi

# Publish to S3
echo "About to upload $destination to $s3_url"
aws s3 cp "$destination" "$s3_url" --storage-class "$S3_STORAGE_TIER" --metadata "DatabaseHost=${DB_HOST},DatabaseName=${DB_NAME}${extra_metadata}"
echo "Upload to $s3_url completed"
