#!/usr/bin/env bash
# Offline-consistent encrypted disaster-recovery backup. Requires root.
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || exit 1
DESTINATION=${1:-/var/backups/mehrvpn}
install -d -m 700 "$DESTINATION"
TASK_BACKUP=$(mktemp -d /var/backups/mehrvpn/stage.XXXXXX)
resume() { systemctl start mehrvpn-agent; systemctl start openvpn-server@server; systemctl start mehrvpn-web; }
cleanup() {
  case "$TASK_BACKUP" in /var/backups/mehrvpn/stage.*) rm -rf -- "$TASK_BACKUP";; esac
  resume
}
trap cleanup EXIT
echo 'Stopping connections briefly for a consistent backup. Enter an encryption password when prompted.'
systemctl stop mehrvpn-web
systemctl stop openvpn-server@server
systemctl stop mehrvpn-agent
tar -C / -czf "$TASK_BACKUP/backup.tar.gz" etc/openvpn/server etc/mehrvpn var/lib/mehrvpn var/lib/mehrvpn-agent etc/nginx/conf.d/mehrvpn.conf etc/systemd/system/openvpn-server@server.service.d/mehrvpn.conf
cd /opt/mehrvpn
/opt/mehrvpn/.venv/bin/python -m panel.backup_crypto encrypt "$TASK_BACKUP/backup.tar.gz" "$DESTINATION/mehrvpn-$(date -u +%Y%m%dT%H%M%SZ).tar.gz.enc"
echo 'Encrypted backup saved. Keep the password separately. See README for restore steps.'
