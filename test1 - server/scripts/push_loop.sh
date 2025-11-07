#!/bin/bash
SCRIPT_TO_RUN="/opt/monitoring/scripts/push_metrics.sh"
SLEEP_TIME=15 # 15 sec por por push on pushgateway

while true; do
    echo "--- $(date +'%Y-%m-%d %H:%M:%S') ---"
    bash "$SCRIPT_TO_RUN" || echo "⚠️ push_metrics.sh failed, continuing loop..."
    sleep $SLEEP_TIME
done

