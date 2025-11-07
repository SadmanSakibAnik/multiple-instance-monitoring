#!/bin/bash
# 🔧 Auto setup systemd service for send_alerts.py

SERVICE_NAME="alertmanager-discord"
WORK_DIR="/opt/monitoring/alertmanager"
SCRIPT_PATH="$WORK_DIR/send_alerts.py"
PYTHON_PATH=$(which python3)
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "❌ $SCRIPT_PATH not found!"
  exit 1
fi

echo "🚀 Setting up $SERVICE_NAME systemd service..."

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Discord Alert Script (Custom AlertManager)
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=${WORK_DIR}
ExecStart=${PYTHON_PATH} ${SCRIPT_PATH}
Restart=always
RestartSec=5
StandardOutput=append:/var/log/${SERVICE_NAME}.log
StandardError=append:/var/log/${SERVICE_NAME}.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ${SERVICE_NAME}

echo "✅ Service '${SERVICE_NAME}' setup complete and running!"
echo "🧠 Logs: sudo journalctl -u ${SERVICE_NAME} -f"
