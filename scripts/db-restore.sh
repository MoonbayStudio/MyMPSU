#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "Usage: $0 backups/mympsu-YYYYMMDD-HHMMSS.sql" >&2
  exit 1
fi

echo "Restoring $1 replaces the current MyMPSU database contents."
printf "Type RESTORE to continue: "
read -r confirmation
if [ "$confirmation" != "RESTORE" ]; then
  echo "Restore cancelled."
  exit 1
fi

docker compose stop api
docker compose exec -T db sh -c 'psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB"' < "$1"
docker compose start api

echo "Database restored from $1"
