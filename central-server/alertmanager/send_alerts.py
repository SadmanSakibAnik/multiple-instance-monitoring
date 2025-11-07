#!/usr/bin/env python3
import requests
import yaml
import time
import os
from datetime import datetime

BASE_DIR = "/opt/monitoring/alertmanager"

def load_yaml(filename):
    path = os.path.join(BASE_DIR, filename)
    if not os.path.exists(path):
        raise FileNotFoundError(f"❌ Config file not found: {path}")
    with open(path, "r") as f:
        return yaml.safe_load(f)

def query_prometheus(prometheus_url, query):
    try:
        response = requests.get(f"{prometheus_url}/api/v1/query", params={"query": query})
        result = response.json()
        if result["status"] == "success":
            return result["data"]["result"]
        return []
    except Exception as e:
        print(f"⚠️ Error querying Prometheus: {e}")
        return []

def send_discord_message(webhook_url, message):
    try:
        payload = {"content": message}
        response = requests.post(webhook_url, json=payload)
        response.raise_for_status()
    except Exception as e:
        print(f"⚠️ Failed to send message to Discord: {e}")

def main():
    config = load_yaml("config.yml")
    webhook_url = config["discord_webhook"]
    prometheus_url = config["prometheus_url"]

    # 🔹 Intervals
    interval = config.get("check_interval", 60)         # Metrics collection frequency
    summary_interval = config.get("summary_interval", 180)  # Summary alert frequency (seconds)
    last_summary_time = 0

    metrics_config = config.get("metrics", {})
    instance_map = config.get("instance_names", {})  # optional friendly name mapping
    last_seen = {}

    while True:
        stats = {}
        all_instances = set()
        now = datetime.now().strftime("%I:%M %p")

        # 🔹 Collect metrics dynamically
        for metric_name, metric_info in metrics_config.items():
            query = metric_info.get("query")
            max_threshold = metric_info.get("max")
            results = query_prometheus(prometheus_url, query)

            for r in results:
                raw_instance = r["metric"].get("exported_instance") or r["metric"].get("instance", "unknown")
                # Skip IPs if no friendly name mapping
                if raw_instance.startswith("10.") and raw_instance not in instance_map:
                    continue
                inst = instance_map.get(raw_instance, raw_instance)

                value = float(r["value"][1])
                all_instances.add(inst)
                last_seen[inst] = time.time()
                stats.setdefault(inst, {})[metric_name] = {
                    "value": value,
                    "max": max_threshold,
                    "emoji": metric_info.get("emoji", "")
                }

        # 🔍 Detect DOWN servers (no data within 2 intervals)
        down_instances = []
        for inst, last_time in list(last_seen.items()):
            if time.time() - last_time > (interval * 2):
                down_instances.append(inst)
                last_seen.pop(inst, None)

        # 🩺 Build Summary & Alerts
        summary_lines = ["🩺 **Server Health Summary**"]
        alert_lines = []

        for inst in sorted(all_instances.union(down_instances)):
            if inst in down_instances:
                summary_lines.append(f"{inst} — 🔴 DOWN")
                alert_lines.append(f"🚨 **ALERT:** {inst} is **DOWN** ❌\n🕒 Today at {now}")
                continue

            instance_metrics = stats.get(inst, {})
            summary_stats = []

            # Ensure all metrics are present, default 0
            for metric_name in metrics_config:
                data = instance_metrics.get(
                    metric_name,
                    {"value": 0, "emoji": metrics_config[metric_name].get("emoji", "")}
                )
                summary_stats.append(
                    f"{data['emoji']}{metric_name}: {data['value']:.2f}{metrics_config[metric_name].get('unit','')}"
                )

            summary_lines.append(f"{inst} — 🟢 UP\n" + " | ".join(summary_stats))

            # ⚠️ Alert if max exceeded
            for metric_name, data in instance_metrics.items():
                if data["max"] is not None and data["value"] > data["max"]:
                    alert_msg = (
                        f"⚠️ Alert: {inst}\n"
                        f"⚠️ {metric_name} {data['value']:.2f}{metrics_config[metric_name].get('unit','')} > "
                        f"{data['max']}{metrics_config[metric_name].get('unit','')}\n\n"
                        "Current Stats\n" + " | ".join(summary_stats) +
                        f"\n🕒 Today at {now}"
                    )
                    alert_lines.append(alert_msg)

        # -------------------- Summary Interval Check --------------------
        if time.time() - last_summary_time >= summary_interval:
            summary_lines.append(f"🕒 Today at {now}")
            send_discord_message(webhook_url, "\n".join(summary_lines))
            for alert in alert_lines:
                send_discord_message(webhook_url, alert)
            last_summary_time = time.time()
        # -----------------------------------------------------------------

        time.sleep(interval)

if __name__ == "__main__":
    main()

