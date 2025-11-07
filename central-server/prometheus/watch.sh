#!/bin/bash
# Prometheus watcher — auto sync + reload (systemd handles background)

BASE_DIR="/opt/monitoring"

# ---------------- CONFIG FILES ----------------
PROM_CONF_SRC="$BASE_DIR/prometheus/prometheus.yml"
PROM_CONF_TARGET="/etc/prometheus/prometheus.yml"

# ---------------- WATCH FUNCTION ----------------
watch_prometheus() {
    echo "🚀 Prometheus watcher started..."
    # inotifywait loop
    while true; do
        inotifywait -e close_write "$PROM_CONF_SRC" >/dev/null 2>&1

        # Sync configs
        sudo cp "$PROM_CONF_SRC" "$PROM_CONF_TARGET"

        # Reload Prometheus via HTTP API
        curl -s -X POST http://10.70.34.180:9090/-/reload >/dev/null

        echo "$(date '+%F %T') - Prometheus config synced & reloaded ✅"
    done
}

# ---------------- SYSTEMD UNIT INSTALLER ----------------
UNIT_FILE="/etc/systemd/system/prometheus-watcher.service"

install_systemd_unit() {
    if [ ! -f "$UNIT_FILE" ]; then
        echo "📦 Installing systemd unit at $UNIT_FILE..."
        sudo tee "$UNIT_FILE" > /dev/null <<EOF
[Unit]
Description=Prometheus Config Watcher
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $BASE_DIR/watch.sh run
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable --now prometheus-watcher.service
        echo "✅ Systemd service 'prometheus-watcher.service' installed and running"
    else
        echo "✅ Systemd unit already installed"
    fi
}

# ---------------- MAIN ----------------
if [ "$1" == "run" ]; then
    watch_prometheus
else
    install_systemd_unit
fi

