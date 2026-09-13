#!/usr/bin/env bash
# Push a new build from your PC to the server.
#
#   ./deploy.sh user@your-server /path/to/exported/linux/build
#
# Exports go up, the service restarts, players reconnect. Takes seconds.
set -euo pipefail
HOST=${1:?usage: deploy.sh user@host /path/to/build-dir}
BUILD=${2:?usage: deploy.sh user@host /path/to/build-dir}
[ -d "$BUILD" ] || { echo "No such build directory: $BUILD"; exit 1; }

echo "==> uploading"
rsync -az --delete --exclude 'backups' "$BUILD"/ "$HOST":/tmp/ironveil-build/
echo "==> installing"
ssh "$HOST" 'sudo rsync -a /tmp/ironveil-build/ /opt/ironveil/ \
  && sudo chown -R ironveil:ironveil /opt/ironveil \
  && sudo chmod +x /opt/ironveil/Ironveil.x86_64 \
  && sudo systemctl restart ironveil \
  && sleep 2 && systemctl is-active ironveil'
echo "==> live"
