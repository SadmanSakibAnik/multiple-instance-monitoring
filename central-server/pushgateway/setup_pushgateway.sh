#!/bin/bash
set -e
echo "🚀 Installing Pushgateway..."

BASE_DIR="/opt/monitoring/pushgateway"
USER="pushgateway"
VERSION="1.9.0"

sudo useradd --no-create-home --shell /usr/sbin/nologin $USER 2>/dev/null || true

cd "$BASE_DIR"
if [ ! -f "pushgateway-${VERSION}.linux-amd64.tar.gz" ]; then
  wget -q https://github.com/prometheus/pushgateway/releases/download/v${VERSION}/pushgateway-${VERSION}.linux-amd64.tar.gz
fi

tar -xzf pushgateway-${VERSION}.linux-amd64.tar.gz
cd pushgateway-${VERSION}.linux-amd64

sudo cp pushgateway /usr/local/bin/
sudo chown $USER:$USER /usr/local/bin/pushgateway

sudo tee /etc/systemd/system/pushgateway.service >/dev/null <<EOF
[Unit]
Description=Prometheus Pushgateway
After=network.target

[Service]
User=$USER
ExecStart=/usr/local/bin/pushgateway --web.listen-address=:9091
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pushgateway
sudo systemctl restart pushgateway

echo "✅ Pushgateway installed on port 9091."
