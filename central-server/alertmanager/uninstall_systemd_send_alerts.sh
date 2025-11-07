#!/bin/bash
# 🔧 Uninstall and cleanup service

SERVICE_NAME="alertmanager-discord"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOG_FILE="/var/log/${SERVICE_NAME}.log"

echo "🛑 Stopping service..."
sudo systemctl stop ${SERVICE_NAME} 2>/dev/null

echo "❌ Disabling service..."
sudo systemctl disable ${SERVICE_NAME} 2>/dev/null

echo "🗑 Removing systemd service file..."
sudo rm -f ${SERVICE_FILE}

echo "🧹 Reloading daemon..."
sudo systemctl daemon-reload

if [ -f "$LOG_FILE" ]; then
  echo "🧽 Removing old logs..."
  sudo rm -f "$LOG_FILE"
fi

echo "✅ '${SERVICE_NAME}' fully uninstalled!"

