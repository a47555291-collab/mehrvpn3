#!/usr/bin/env bash
set -eu
cd /opt/mehrvpn
exec /opt/mehrvpn/.venv/bin/python -m panel.hook
