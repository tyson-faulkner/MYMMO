#!/usr/bin/env bash
# Kingsmourn — fresh Ubuntu 24.04 box to a running server, one command.
#
#   scp -r deploy/ user@your-server:~/
#   ssh user@your-server
#   cd deploy && chmod +x setup.sh && sudo ./setup.sh
#
# Safe to run twice: every step checks before it acts.
set -euo pipefail

APP_DIR=/opt/kingsmourn
LOG_DIR=/var/log/kingsmourn
SERVICE_USER=kingsmourn

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo."; exit 1; }

say "Packages"
apt-get update -qq
apt-get install -y -qq ca-certificates curl ufw unzip

say "Docker"
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "already installed"
fi

say "Service user and folders"
id -u "$SERVICE_USER" >/dev/null 2>&1 || useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
mkdir -p "$APP_DIR" "$LOG_DIR" "$APP_DIR/backups"
chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR" "$LOG_DIR"

say "Secrets"
if [ ! -f .env ]; then
  cp .env.example .env
  # Generate real secrets rather than shipping the placeholders.
  KEY=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 40)
  PW=$(head -c 24 /dev/urandom | base64 | tr -d '/+=' | head -c 28)
  sed -i "s|^NAKAMA_SERVER_KEY=.*|NAKAMA_SERVER_KEY=${KEY}|" .env
  sed -i "s|^NAKAMA_CONSOLE_PASSWORD=.*|NAKAMA_CONSOLE_PASSWORD=${PW}|" .env
  chmod 600 .env
  echo "Generated .env. Your client needs this server key:"
  echo "    ${KEY}"
  echo "Console password (write it down, it is not shown again):"
  echo "    ${PW}"
else
  echo ".env already exists, leaving it alone"
fi

say "Firewall"
ufw allow OpenSSH >/dev/null
ufw allow 7350/tcp comment 'Nakama API' >/dev/null
ufw allow 8080/tcp comment 'Kingsmourn game' >/dev/null
ufw allow 8080/udp comment 'Kingsmourn game' >/dev/null
ufw --force enable >/dev/null
echo "open: 22, 7350/tcp, 8080/tcp+udp. Database and Nakama console stay private."

say "Backend"
cp docker-compose.yml .env "$APP_DIR"/ 2>/dev/null || true
(cd "$APP_DIR" && docker compose up -d)

say "Game server service"
cp kingsmourn.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable kingsmourn >/dev/null
if [ -x "$APP_DIR/Kingsmourn.x86_64" ]; then
  systemctl restart kingsmourn
  echo "started"
else
  echo "No game build at $APP_DIR/Kingsmourn.x86_64 yet."
  echo "Export a Linux build from Godot, then run ./deploy.sh from your PC."
fi

say "Nightly backup"
cp backup.sh "$APP_DIR"/ && chmod +x "$APP_DIR/backup.sh"
cat > /etc/cron.d/kingsmourn-backup <<'CRON'
# Seven rolling nightly backups. Losing everyone's characters would end the
# project; this is the two minutes that prevents it.
30 4 * * * root /opt/kingsmourn/backup.sh >> /var/log/kingsmourn/backup.log 2>&1
CRON

say "Done"
echo "Backend:  docker compose -f $APP_DIR/docker-compose.yml ps"
echo "Game:     systemctl status kingsmourn"
echo "Logs:     tail -f $LOG_DIR/server.log"
echo "Console:  ssh -L 7351:localhost:7351 $SUDO_USER@\$(hostname -I | awk '{print \$1}')  then http://localhost:7351"
