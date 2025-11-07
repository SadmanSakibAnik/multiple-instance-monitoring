#!/bin/bash
set -e
echo "🧹 Uninstalling Prometheus..."

sudo systemctl stop prometheus 2>/dev/null || true
sudo systemctl disable prometheus 2>/dev/null || true
sudo rm -f /etc/systemd/system/prometheus.service
sudo systemctl daemon-reload

sudo rm -rf /etc/prometheus /var/lib/prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
sudo userdel prometheus 2>/dev/null || true

echo "✅ Prometheus removed cleanly."

