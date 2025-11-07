# Centralized Monitoring Setup

This guide explains how to set up a **centralized monitoring system** using **Node Exporter**, **cAdvisor**, **Pushgateway**, **Prometheus**, **Alertmanager (Discord Integration)**, **Loki**, and **Grafana**.

---



## Flow Summary

```
[Instance: Node Exporter + cAdvisor] → Pushgateway → Prometheus → Grafana
                                      ↘ Alertmanager (Discord)
                                      ↘ Loki → Grafana Logs Visualization
```




## 🧠 Architecture Overview

- **Central Server** collects and visualizes metrics.
- **Multiple Instances** (e.g., `test1`, `test2`) push metrics to the central server through **Pushgateway**.
- **Prometheus** pulls data from **Pushgateway**.
- **Grafana** visualizes all data (Prometheus + Loki).
- **Alertmanager (Discord)** sends alerts based on thresholds.

### **Central Server Structure**
```
central-server/
├── alertmanager
│   ├── config.yml
│   ├── send_alerts.py
│   ├── systemd_send_alerts.sh
│   └── uninstall_systemd_send_alerts.sh
├── prometheus
│   ├── prometheus
│   ├── prometheus.yml
│   ├── setup_prometheus.sh
│   ├── uninstall_prometheus.sh
│   └── watch.sh
└── pushgateway
    ├── setup_pushgateway.sh
    └── uninstall_pushgateway.sh
```

---

## ⚙️ Grafana Installation

```bash
#Install the prerequisite packages:
sudo apt-get install -y apt-transport-https software-properties-common wget

#Import the GPG key:
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

#To add a repository for stable releases, run the following command:
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

#Run the following command to update the list of available packages:
sudo apt-get update
#To install Grafana OSS, run the following command:
sudo apt-get install grafana

#Start Grafana server
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
sudo systemctl status grafana-server
```

**Login Credentials:**
```
Username: admin
Password: admin
```

---

## 📜 Loki Installation

### 1. Create Loki User & Directories
```bash
sudo useradd --no-create-home --shell /bin/false loki
sudo mkdir -p /var/lib/loki /var/log/loki
sudo chown -R loki:loki /var/lib/loki /var/log/loki
```

### 2. Download & Install Loki
```bash
LokiVersion="3.5.6"
wget https://github.com/grafana/loki/releases/download/v${LokiVersion}/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
sudo mv loki-linux-amd64 /usr/local/bin/loki
sudo chmod +x /usr/local/bin/loki
#Verify the installation:
loki --version
```

### 3. Configuration
```bash
sudo mkdir -p /etc/loki
sudo vim /etc/loki/config.yaml
```

Paste the provided Loki config content.

Set permissions:
```bash
sudo chown -R loki:loki /etc/loki
```

### 4. Systemd Service
`/etc/systemd/system/loki.service`
```ini
[Unit]
Description=Grafana Loki
After=network.target

[Service]
User=loki
Group=loki
Type=simple
ExecStart=/usr/local/bin/loki --config.file=/etc/loki/config.yaml
Restart=on-failure
LimitNOFILE=65536
StandardOutput=file:/var/log/loki/loki.log
StandardError=file:/var/log/loki/loki-error.log

[Install]
WantedBy=multi-user.target
```

### 5. Enable & Start
```bash
sudo systemctl daemon-reload
sudo systemctl enable loki
sudo systemctl start loki
sudo systemctl status loki
cd /var/lib/loki            # loki data store hoi
```

---

## 🔥 Prometheus Setup

### Steps
1. Make all the script executable and run:
   ```bash
   sudo chmod +x setup_prometheus.sh
   ./setup_prometheus.sh
   ```
2. To uninstall:
   ```bash
   ./uninstall_prometheus.sh
   ```
3. File Synchronization:

   - `watch.sh` keeps `/etc/prometheus/prometheus.yml` synced with local copy.
   - Requires `inotifywait`. for installation,
   ```bash
   sudo apt install inotify-tools -y
   ```
   - Ensure systemd service is enabled.

4. In `prometheus.yml`, add Pushgateway target:
   ```yaml
   - job_name: 'pushgateway'
     static_configs:
       - targets: ['<pushgateway_ip>:9091']
   ```

### Useful commands: 

```bash
sudo systemctl restart prometheus
sudo systemctl start prometheus
cat /etc/prometheus/prometheus.yml                  # prometheus er endpoint gula add korte hoi
cat /etc/systemd/system/prometheus.service          # systemd file retansion on
cd /var/lib/prometheus/
```

---

## 🚀 Pushgateway Setup

1. Run setup script:
   ```bash
   ./setup_pushgateway.sh
   ```
2. To uninstall:
   ```bash
   ./uninstall_pushgateway.sh
   ```

---

## 🚨 Alertmanager (Discord Integration)

1. **Discord Webhook:**
   - Go to Discord → Server Settings → Integrations → Webhooks → Copy URL.

2. **Configuration Files:**
   - `config.yml` → Set Discord webhook, Prometheus URL, and alert thresholds.
   - `send_alerts.py` → Sends alerts to Discord. necessary commands for python3:
   ```bash
   sudo apt install python3
   sudo apt install python3-pip
   ```
   - `systemd_send_alerts.sh` → Runs background service.
   Run setup script:
   ```bash
   ./systemd_send_alerts.sh
   ```
   - `uninstall_systemd_send_alerts.sh` → Removes setup completely.

### Discord-alertmanager useful commands:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now alertmanager-discord
sudo systemctl status alertmanager-discord
```
---

## 📊 Grafana Data Sources

### Prometheus Data Source
1. Open Grafana → `http://<central-ip>:3000`
2. Add Data Source → Prometheus
3. URL: `http://<central-ip>:9090`
4. Save & Test
#### -> Cadvisor Docker dashboard id = 14282

### Loki Data Source
1. Add Data Source → Loki
2. URL: `http://<central-ip>:3100`
3. Save & Test

---

## 🖥️ Multiple Instance Setup

## Prerequiests:
1. Docker
2. Docker Compose

# Docker installation:

```bash
sudo curl -fsSL https://get.docker.com/ -o get-docker.sh
sudo sh get-docker.sh
```

Each instance (e.g., `test1`) runs **Node Exporter** and **cAdvisor** in Docker, and pushes metrics to **Central Pushgateway**.

### Folder Structure (per instance)
```
├── cadvisor
│   └── docker-compose.yml
├── node-exporter
│   └── docker-compose.yml
└── scripts
    ├── push_loop.sh
    ├── push_metrics.service
    └── push_metrics.sh
```

### Prerequisites
- Docker & Docker Compose installed.

### Setup Steps
1. **Run cAdvisor:**
   ```bash
   cd cadvisor
   docker compose up -d
   ```
2. **Run Node Exporter:**
   ```bash
   cd node-exporter
   docker compose up -d
   ```

### Push Scripts
- `push_metrics.sh` → Pushes metrics to Pushgateway.
  ```bash
  CENTRAL_PUSHGATEWAY="http://<central_ip>:9091"
  TARGET_HOST="<instance_ip>"
  ```
- `push_metrics.service` → Keeps metrics pushing in background via systemd.
- `push_loop.sh` → Constantly loops metrics push.

---


## For Docker driver plugins: Sends logs to the central server

```bash
docker plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions

```
## For validation: 
```bash
docker plugin ls
```

# Docker Driver Configuration:

```bash

vim /etc/docker/daemon.json

```
daemon.json:
```
{
    "debug": true,
    "log-driver": "loki",
    "log-opts": {
        "loki-url": "http://10.70.34.180:3100/loki/api/v1/push", # your centralIP
        "loki-batch-size": "400",
        "loki-retries": "3",
        "loki-max-backoff": "1s",
        "loki-timeout": "1s",
        "keep-file": "true",
        "no-file": "false",
        "max-size": "500m",
        "max-file": "3"
    }
}
```



## 🧩 Useful Ports
| Service | Default Port |
|----------|---------------|
| Grafana | 3000 |
| Prometheus | 9090 |
| Pushgateway | 9091 |
| Loki | 3100 |


---

## 🧰 Uninstall Guides
| Component | Uninstall Command |
|------------|------------------|
| Prometheus | `./uninstall_prometheus.sh` |
| Pushgateway | `./uninstall_pushgateway.sh` |
| Alertmanager | `./uninstall_systemd_send_alerts.sh` |

---


