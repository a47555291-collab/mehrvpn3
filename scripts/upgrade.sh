#!/usr/bin/env bash
# Run this from a reviewed new release on an existing installation.
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root'; exit 1; }
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$SOURCE_DIR" != /opt/mehrvpn ]] || { echo 'Run from the newly extracted release, not /opt/mehrvpn.'; exit 1; }
[[ -f /etc/mehrvpn/panel.env ]] || { echo 'MehrVPN is not installed'; exit 1; }
bash /opt/mehrvpn/scripts/backup.sh
systemctl stop mehrvpn-web
systemctl stop openvpn-server@server
systemctl stop mehrvpn-agent
cp -a "$SOURCE_DIR/panel/." /opt/mehrvpn/panel/
cp -a "$SOURCE_DIR/scripts/." /opt/mehrvpn/scripts/
install -m 644 "$SOURCE_DIR/requirements.txt" /opt/mehrvpn/requirements.txt
install -m 644 "$SOURCE_DIR/constraints.txt" /opt/mehrvpn/constraints.txt
find /opt/mehrvpn/panel /opt/mehrvpn/scripts -type d -exec chmod 755 {} +
find /opt/mehrvpn/panel -type f -exec chmod 644 {} +
chmod 755 /opt/mehrvpn/scripts/*.sh
/opt/mehrvpn/.venv/bin/pip install -r /opt/mehrvpn/requirements.txt
cp /opt/mehrvpn/scripts/mehrvpn-{agent,web}.service /etc/systemd/system/
systemctl daemon-reload
systemctl start mehrvpn-agent
for _ in {1..30}; do [[ -S /run/mehrvpn/control.sock ]] && break; sleep 1; done
systemctl start openvpn-server@server
systemctl start mehrvpn-web
echo 'Updated. Check the dashboard and make a real client connection before accepting the release.'
