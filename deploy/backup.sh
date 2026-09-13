#!/usr/bin/env bash
# Nightly database snapshot, seven kept. Run by cron; safe to run by hand.
set -euo pipefail
DIR=/opt/ironveil/backups
STAMP=$(date +%Y-%m-%d)
mkdir -p "$DIR"
docker exec "$(docker ps -qf name=cockroachdb)" \
  ./cockroach sql --insecure --execute "BACKUP INTO 'nodelocal://1/${STAMP}';" 2>/dev/null \
  || docker run --rm -v ironveil_ironveil-db:/src -v "$DIR":/dest alpine \
       tar czf "/dest/ironveil-${STAMP}.tar.gz" -C /src .
find "$DIR" -name 'ironveil-*.tar.gz' -mtime +7 -delete
echo "$(date -Is) backup ok"
