#!/bin/bash
set -e

GREEN="\e[32m"; RED="\e[31m"; CYAN="\e[36m"; RESET="\e[0m"
echo -e "${CYAN}🚀 Installing Prometheus (Binary Mode)...${RESET}"

cd "$(dirname "$0")"
BASE_DIR="/opt/monitoring/prometheus"
USER="prometheus"
VERSION="3.7.1"

sudo useradd --no-create-home --shell /usr/sbin/nologin $USER 2>/dev/null || true
sudo mkdir -p /etc/prometheus /var/lib/prometheus

if [ ! -f "prometheus-${VERSION}.linux-amd64.tar.gz" ]; then
  wget -q https://github.com/prometheus/prometheus/releases/download/v${VERSION}/prometheus-${VERSION}.linux-amd64.tar.gz
fi

tar -xzf prometheus-${VERSION}.linux-amd64.tar.gz
cd prometheus-${VERSION}.linux-amd64

sudo cp prometheus promtool /usr/local/bin/
sudo cp -r consoles console_libraries /etc/prometheus/ 2>/dev/null || echo "⚠️  Consoles not found (skipped)."
sudo cp "${BASE_DIR}/prometheus.yml" /etc/prometheus/prometheus.yml

sudo chown -R $USER:$USER /etc/prometheus /var/lib/prometheus

sudo tee /etc/systemd/system/prometheus.service >/dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
User=$USER
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --storage.tsdb.retention.time=15d \\
  --web.listen-address=:9090
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl restart prometheus

echo -e "${GREEN}✅ Prometheus installed and running on port 9090.${RESET}"
