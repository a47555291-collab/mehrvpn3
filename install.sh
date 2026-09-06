#!/usr/bin/env bash
# Run locally from a reviewed release: sudo bash install.sh
set -Eeuo pipefail
umask 077
[[ ${EUID} -eq 0 ]] || { echo 'Run with sudo bash install.sh'; exit 1; }
source /etc/os-release
case "$ID:$VERSION_ID" in ubuntu:22.04|ubuntu:24.04|debian:12|debian:13) ;; *) echo 'Supported: Ubuntu 22.04/24.04 and Debian 12/13.'; exit 1;; esac
[[ -e /dev/net/tun ]] || { echo 'The server requires an enabled TUN device.'; exit 1; }
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=/opt/mehrvpn
VPN_CONFIG=/etc/openvpn/server/server.conf
if [[ -f /etc/mehrvpn/panel.env ]]; then
  echo 'MehrVPN is already installed. Use scripts/upgrade.sh to update without resetting your data.'
  exit 1
fi
command -v systemctl >/dev/null
if [[ -f "$VPN_CONFIG" ]]; then
  if grep -Eq '^[[:space:]]*(management|client-connect|client-disconnect|duplicate-cn|plugin|auth-user-pass-verify)[[:space:]]' "$VPN_CONFIG"; then
    echo 'This OpenVPN installation has custom authentication, hooks, management or duplicate-cn. Review integration manually; nothing was changed.'
    exit 1
  fi
fi
printf '\nMehrVPN / OpenVPN panel\n'
read -r -p 'Server public IP or domain (no https://): ' PANEL_HOST
[[ "$PANEL_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,252}$ ]] || { echo 'Invalid hostname'; exit 1; }
read -r -p 'HTTPS panel port [8443]: ' PANEL_PORT
PANEL_PORT=${PANEL_PORT:-8443}
[[ "$PANEL_PORT" =~ ^[0-9]{1,5}$ ]] && ((10#$PANEL_PORT >= 1 && 10#$PANEL_PORT <= 65535)) || { echo 'Invalid port'; exit 1; }
PANEL_PORT=$((10#$PANEL_PORT))
if ss -ltnH "sport = :$PANEL_PORT" | grep -q .; then echo 'The panel port is already in use.'; exit 1; fi
read -r -p 'Owner username [admin]: ' PANEL_ADMIN
PANEL_ADMIN=${PANEL_ADMIN:-admin}
[[ "$PANEL_ADMIN" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,47}$ && "$PANEL_ADMIN" != 'server' && "$PANEL_ADMIN" != 'ca' ]] || { echo 'Invalid username'; exit 1; }
apt-get update
apt-get install -y python3 python3-venv python3-pip nginx openssl curl ca-certificates
python3 - "$SOURCE_DIR" <<'PY'
import hashlib,json,sys,pathlib
p=pathlib.Path(sys.argv[1]); source=json.loads((p/'vendor/source.json').read_text())
assert hashlib.sha256((p/'vendor/openvpn-install.sh').read_bytes()).hexdigest()==source['sha256'], 'Upstream installer checksum mismatch'
PY
install -d -m 755 "$INSTALL_DIR"
cp -a "$SOURCE_DIR/panel" "$SOURCE_DIR/vendor" "$SOURCE_DIR/scripts" "$INSTALL_DIR/"
install -m 644 "$SOURCE_DIR/requirements.txt" "$INSTALL_DIR/requirements.txt"
install -m 644 "$SOURCE_DIR/constraints.txt" "$INSTALL_DIR/constraints.txt"
find "$INSTALL_DIR" -type d -exec chmod 755 {} +
find "$INSTALL_DIR" -type f -exec chmod 644 {} +
if [[ ! -f "$VPN_CONFIG" ]]; then
  echo 'Starting the unchanged upstream OpenVPN installer. Choose your VPN port, protocol and DNS.'
  # Keep the upstream-generated private profile out of the public application directory.
  install -d -m 700 /root/mehrvpn-bootstrap
  install -m 700 "$SOURCE_DIR/vendor/openvpn-install.sh" /root/mehrvpn-bootstrap/openvpn-install.sh
  bash /root/mehrvpn-bootstrap/openvpn-install.sh
fi
[[ -f "$VPN_CONFIG" && -x /etc/openvpn/server/easy-rsa/easyrsa && -f /etc/openvpn/server/client-common.txt ]] || { echo 'OpenVPN installation is incomplete.'; exit 1; }
systemctl is-active --quiet openvpn-server@server.service || { echo 'OpenVPN must be healthy before adding the panel.'; exit 1; }
python3 - <<'PY'
import pathlib,re
vpn=pathlib.Path('/etc/openvpn/server')
config=(vpn/'server.conf').read_text()
for key,expected in [('user','nobody'),('group','nogroup')]:
    found=re.search(r'^'+key+r'\s+(\S+)',config,re.M)
    if not found or found.group(1)!=expected:
        raise SystemExit('OpenVPN user/group differs from the supported upstream setup. Review hook permissions first.')
for line in (vpn/'easy-rsa/pki/index.txt').read_text().splitlines():
    fields=line.split('\t')
    if len(fields)<6 or fields[0]!='V' or '/CN=' not in fields[-1]: continue
    name=fields[-1].split('/CN=')[-1]
    if name.lower() not in {'server','ca'} and not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_-]{0,47}',name):
        raise SystemExit('Existing client name is not supported by this panel: '+name+'. Review migration before installing.')
PY
getent passwd mehrvpn >/dev/null || useradd --system --home /var/lib/mehrvpn --shell /usr/sbin/nologin mehrvpn
install -d -o mehrvpn -g mehrvpn -m 700 /var/lib/mehrvpn
install -d -m 700 /var/lib/mehrvpn-agent /etc/mehrvpn /etc/mehrvpn/tls /var/backups/mehrvpn
python3 -m venv "$INSTALL_DIR/.venv"
"$INSTALL_DIR/.venv/bin/pip" install --disable-pip-version-check -r "$INSTALL_DIR/requirements.txt"
PANEL_ORIGIN="https://$PANEL_HOST:$PANEL_PORT"
[[ "$PANEL_PORT" != 443 ]] || PANEL_ORIGIN="https://$PANEL_HOST"
printf 'MEHRVPN_DB=/var/lib/mehrvpn/panel.db\nMEHRVPN_PUBLIC_URL=%s\n' "$PANEL_ORIGIN" > /etc/mehrvpn/panel.env
cd "$INSTALL_DIR"
echo 'Create the owner password. This password is never stored in plain text.'
MEHRVPN_DB=/var/lib/mehrvpn/panel.db "$INSTALL_DIR/.venv/bin/python" -m panel.cli owner --username "$PANEL_ADMIN"
chown -R mehrvpn:mehrvpn /var/lib/mehrvpn
cp -p "$VPN_CONFIG" /var/backups/mehrvpn/server.conf.before-panel
install -d -m 755 /etc/systemd/system/openvpn-server@server.service.d
rollback() {
  echo 'Panel setup failed. Restoring the original OpenVPN configuration.'
  # Stop the policy monitor first, otherwise it would stop the restored VPN
  # when the management socket disappears.
  systemctl disable --now mehrvpn-web.service mehrvpn-agent.service 2>/dev/null || true
  cp -p /var/backups/mehrvpn/server.conf.before-panel "$VPN_CONFIG"
  rm -f /etc/systemd/system/openvpn-server@server.service.d/mehrvpn.conf
  rm -f /etc/nginx/conf.d/mehrvpn.conf
  if nginx -t; then systemctl reload nginx || true; fi
  systemctl daemon-reload
  systemctl restart openvpn-server@server.service || true
  echo 'Inspect journalctl -u mehrvpn-agent -u mehrvpn-web. Files remain available for diagnosis.'
}
trap rollback ERR
cat >> "$VPN_CONFIG" <<'CONF'

# BEGIN MEHRVPN: policy and accounting only; protocol/ciphers/PKI unchanged
management /run/mehrvpn/management.sock unix
management-client-user root
script-security 2
client-connect /opt/mehrvpn/scripts/openvpn-hook.sh
client-disconnect /opt/mehrvpn/scripts/openvpn-hook.sh
# END MEHRVPN
CONF
chmod 755 "$INSTALL_DIR/scripts/"*.sh
cp "$INSTALL_DIR/scripts/mehrvpn-agent.service" /etc/systemd/system/
cp "$INSTALL_DIR/scripts/mehrvpn-web.service" /etc/systemd/system/
cat > /etc/systemd/system/openvpn-server@server.service.d/mehrvpn.conf <<'UNIT'
[Unit]
BindsTo=mehrvpn-agent.service
After=mehrvpn-agent.service
[Service]
ReadWritePaths=/run/mehrvpn
UNIT
if [[ "$PANEL_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then SAN="IP:$PANEL_HOST"; else SAN="DNS:$PANEL_HOST"; fi
openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
  -keyout /etc/mehrvpn/tls/panel.key -out /etc/mehrvpn/tls/panel.crt \
  -subj "/CN=$PANEL_HOST" -addext "subjectAltName=$SAN" 2>/dev/null
cat > /etc/nginx/conf.d/mehrvpn.conf <<NGINX
server {
    listen $PANEL_PORT ssl;
    server_name $PANEL_HOST;
    ssl_certificate /etc/mehrvpn/tls/panel.crt;
    ssl_certificate_key /etc/mehrvpn/tls/panel.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    client_max_body_size 16k;
    add_header Strict-Transport-Security "max-age=31536000" always;
    location / {
        proxy_pass http://127.0.0.1:8097;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_read_timeout 110s;
        # Tokens and private profile URLs must not enter proxy access logs.
        access_log off;
    }
}
NGINX
nginx -t
systemctl daemon-reload
systemctl enable --now mehrvpn-agent.service
for _ in {1..30}; do [[ -S /run/mehrvpn/control.sock ]] && break; sleep 1; done
[[ -S /run/mehrvpn/control.sock ]]
systemctl restart openvpn-server@server.service
systemctl enable --now mehrvpn-web.service
systemctl enable --now nginx
systemctl reload nginx
for _ in {1..30}; do if curl -fsS http://127.0.0.1:8097/api/health >/dev/null; then break; fi; sleep 1; done
curl -fsS http://127.0.0.1:8097/api/health >/dev/null
systemctl is-active --quiet openvpn-server@server.service
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then ufw allow "$PANEL_PORT/tcp" comment MehrVPN; fi
if systemctl is-active --quiet firewalld; then firewall-cmd --permanent --add-port="$PANEL_PORT/tcp"; firewall-cmd --add-port="$PANEL_PORT/tcp"; fi
trap - ERR
printf '\nMehrVPN installed: %s\nOwner: %s\n' "$PANEL_ORIGIN" "$PANEL_ADMIN"
echo 'Allow the panel TCP port in your cloud firewall as well.'
echo 'HTTPS uses a self-signed certificate. Compare this fingerprint before trusting it:'
openssl x509 -in /etc/mehrvpn/tls/panel.crt -noout -fingerprint -sha256
echo 'For trusted browser HTTPS, replace panel.crt/panel.key with a certificate for your domain, then reload nginx.'
echo 'Client quotas start at installation. Imported clients do not include historical usage.'
