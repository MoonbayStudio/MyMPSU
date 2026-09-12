#!/usr/bin/env sh
set -eu

mkdir -p backups
timestamp="$(date '+%Y%m%d-%H%M%S')"
output="backups/mympsu-${timestamp}.sql"

docker compose exec -T db sh -c 'pg_dump \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges' > "$output"

echo "Database backup written to $output"
