#!/bin/bash
set -e
echo "🧹 Uninstalling Pushgateway..."

sudo systemctl stop pushgateway 2>/dev/null || true
sudo systemctl disable pushgateway 2>/dev/null || true
sudo rm -f /etc/systemd/system/pushgateway.service
sudo systemctl daemon-reload

sudo rm -rf /usr/local/bin/pushgateway
sudo userdel pushgateway 2>/dev/null || true

echo "✅ Pushgateway removed cleanly."
