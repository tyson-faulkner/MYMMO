#!/usr/bin/env bash
# Nightly database snapshot, seven kept. Run by cron; safe to run by hand.
set -euo pipefail
DIR=/opt/kingsmourn/backups
STAMP=$(date +%Y-%m-%d)
mkdir -p "$DIR"
docker exec "$(docker ps -qf name=cockroachdb)" \
  ./cockroach sql --insecure --execute "BACKUP INTO 'nodelocal://1/${STAMP}';" 2>/dev/null \
  || docker run --rm -v kingsmourn_kingsmourn-db:/src -v "$DIR":/dest alpine \
       tar czf "/dest/kingsmourn-${STAMP}.tar.gz" -C /src .
find "$DIR" -name 'kingsmourn-*.tar.gz' -mtime +7 -delete
echo "$(date -Is) backup ok"
