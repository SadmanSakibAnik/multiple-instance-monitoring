#!/bin/bash
set -e

CENTRAL_PUSHGATEWAY="http://10.70.34.180:9091"
INSTANCE_NAME="test1"

# The host where Node Exporter and cAdvisor are running
TARGET_HOST="192.168.56.20"
NODE_EXPORTER_URL="http://$TARGET_HOST:9100/metrics"
CADVISOR_URL="http://$TARGET_HOST:8080/metrics"

TMP_DIR="/tmp/metrics_push"
mkdir -p "$TMP_DIR"

echo "📡 Pushing metrics from $INSTANCE_NAME ..."

# -------------------- CLEANER FUNCTION --------------------
clean_metrics() {
    local src_url=$1
    local dst_file=$2
    local job_name=$3
    
    # 1. Fetch metrics and initial cleanup (empty lines, NaN/Inf, and timestamp removal)
    local RAW_FILE="$TMP_DIR/raw_${job_name}_${INSTANCE_NAME}.txt"

    curl -fs "$src_url" \
        | grep -Ev '^\s*$' \
        | grep -v 'NaN' | grep -v 'Inf' \
        | sed '/^[^#]/s/\s[0-9]\{13,\}$//g' \
        > "$RAW_FILE"

    # --- CRITICAL FIX for Pushgateway Type Error (HTTP 400) and cAdvisor cleanup ---
    if [[ "$job_name" == "cadvisor" ]]; then
        local CADVISOR_CLEAN="$TMP_DIR/cadvisor_clean_temp.txt"
        
        # We need to filter out cAdvisor's Go-runtime and process metrics 
        # as they often conflict with other metrics or are poorly typed for Pushgateway.
        # We also still filter the problematic high-cardinality container CPU metrics.
        
        # Keywords for cAdvisor-specific metrics (container metrics)
        CADVISOR_KEYWORDS="(container_|cpu_|memory_|disk_|filesystem_|network_)"
        
        # 1. Copy over all cAdvisor metric lines that match the keywords AND all HELP/TYPE lines
        #    Filtering out go_*, process_*, and problematic container CPU lines
        
        # a) Keep all HELP/TYPE lines
        grep -E '^(#HELP|#TYPE)' "$RAW_FILE" > "$CADVISOR_CLEAN"
        
        # b) Append only the metric lines that start with cAdvisor keywords AND are NOT problematic CPU lines
        grep -E '^[^#]' "$RAW_FILE" \
            | grep -E "$CADVISOR_KEYWORDS" \
            | grep -v 'container_cpu_usage_seconds_total{.*(id=|name=).*' \
            | grep -v 'go_' \
            | grep -v 'process_' \
            >> "$CADVISOR_CLEAN"
        
        # 2. Use the cleaned version
        mv "$CADVISOR_CLEAN" "$dst_file"
    else
        # For Node Exporter (or others), just use the raw file (already cleaned for timestamps)
        mv "$RAW_FILE" "$dst_file"
    fi

    # Check the curl exit status after the initial fetch
    if [ $? -ne 0 ]; then
        echo "⚠️ WARNING: Failed to fetch metrics from $src_url for job $job_name. Skipping push." 1>&2
        # Ensure file is empty if fetching failed, and return 1
        >"$dst_file"
        return 1
    fi
    # ----------------------------------------------------

    # Ensure a final newline for proper file formatting
    echo "" >> "$dst_file"
    return 0
}

# -------------------- PUSH FUNCTION (No Change Required) --------------------
push_to_gateway() {
    local file=$1
    local job=$2
    local url="$CENTRAL_PUSHGATEWAY/metrics/job/$job/instance/$INSTANCE_NAME"

    # Check if the file is empty (meaning fetching failed)
    if [ ! -s "$file" ]; then
        echo "❌ $job push skipped: Metric file is empty."
        return 1
    fi

    # Use -X PUT for a clean push that replaces all metrics for this job/instance
    http_code=$(curl -s -o /tmp/push_resp.txt -w "%{http_code}" -X PUT --data-binary @"$file" "$url")

    if [[ "$http_code" == "202" || "$http_code" == "200" ]]; then
        echo "✅ $job metrics pushed successfully"
    else
        echo "❌ Push failed (HTTP $http_code)"
        cat /tmp/push_resp.txt
    fi
}
# -------------------- EXECUTION --------------------

# Node Exporter
NODE_FILE="$TMP_DIR/node_${INSTANCE_NAME}.txt"
clean_metrics "$NODE_EXPORTER_URL" "$NODE_FILE" "node_exporter"
push_to_gateway "$NODE_FILE" "node_exporter"

# cAdvisor
CADVISOR_FILE="$TMP_DIR/cadvisor_${INSTANCE_NAME}.txt"
if clean_metrics "$CADVISOR_URL" "$CADVISOR_FILE" "cadvisor"; then
    push_to_gateway "$CADVISOR_FILE" "cadvisor"
fi

echo "🎯 All push attempts completed from $INSTANCE_NAME"
exit 0

