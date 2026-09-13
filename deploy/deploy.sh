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
rsync -az --delete --exclude 'backups' "$BUILD"/ "$HOST":/tmp/kingsmourn-build/
echo "==> installing"
ssh "$HOST" 'sudo rsync -a /tmp/kingsmourn-build/ /opt/kingsmourn/ \
  && sudo chown -R kingsmourn:kingsmourn /opt/kingsmourn \
  && sudo chmod +x /opt/kingsmourn/Kingsmourn.x86_64 \
  && sudo systemctl restart kingsmourn \
  && sleep 2 && systemctl is-active kingsmourn'
echo "==> live"
