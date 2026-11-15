#!/usr/bin/env bash
# Run on EC2 as root using the workload IAM instance role.
# Backups include PII: store only in the encrypted, private S3 bucket.
set -euo pipefail
umask 077
if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^[a-z0-9.-]+$ ]]; then
  echo "Usage: backup-db.sh <private-s3-bucket>" >&2
  exit 2
fi
cd /opt/weutube
BACKUP_KEY="backups/$(date -u +%Y/%m/%d)/weutube-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
docker compose exec -T postgres pg_dump -U weutube -d weutube \
  | gzip -9 \
  | aws s3 cp - "s3://$1/$BACKUP_KEY" --sse AES256 --region ap-south-1 --only-show-errors
echo "WeuTube database backup uploaded to private S3"
