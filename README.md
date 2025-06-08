## 📊 Hybrid Infrastructure Monitoring with Prometheus & Grafana

### 🔧 Monitor On-Prem & AWS EC2 Nodes with Secure Metric Collection
This project demonstrates how to set up a **Prometheus + Grafana** monitoring stack that can securely collect metrics from both **on-premises (VMware-based RHEL)** and **cloud-based (AWS EC2)** servers.

It simulates a **real-world hybrid environment** with:

* **Dev environment** running on a local laptop (WSL2 + VMware)
* **Prod environment** running on AWS (EC2 instances in a VPC)
* Secure access using **OpenVPN** and **Nginx reverse proxy**


---

## 🖼️ Architecture Overview

![Hybrid Monitoring Architecture](prometheus_hybrid_monitoring_proj\img\prometheus_hybrid_monitoring_architecture.gif)

---

## 🌍 Environments

### 🔹 Development (WSL2 in Laptop)

* Prometheus & Grafana running inside WSL2
* RHEL VM (VMware) running Node Exporter
* EC2 instance as remote target via public IP
* Access to metrics via:(prometheus.yml file)

  * `RHEL VM` → private IP
  * `EC2` → public IP with restricted access (MY Public IP TCP 9100)
  Note:
  * If you have openvpn server in AWS, than connect WSL2 to openvpn server:
    in this case 
    * `EC2` → private IP of the EC2 instance as target in prometheus.yml file and add openvpn private IP inside EC2 secuirty group tcp 9100

### 🔸 Production (AWS VPC)

* Prometheus & Grafana on EC2 monitoring node
* Another EC2 target node in same VPC (private IP access)
* RHEL VM metrics exposed via OpenVPN + Nginx reverse proxy

---

## 🔐 Security Practices

* Only **authorized IPs** are allowed on port `9100`
* **Reverse proxy (Nginx)** used to route requests from VPN server to local VM
* **OpenVPN** connects RHEL VM securely to AWS network
* **Prometheus targets restricted** to trusted subnets

Below you can able to see the security groups used for production environment
![OpenVPN sg](prometheus_hybrid_monitoring_proj\img\prod_env\openvpn_sg.png)
![Monitoring instance secuirty group](prometheus_hybrid_monitoring_proj\img\prod_env\monitoring_EC2_sg.png)
![EC2 with node exporter secuirty group](prometheus_hybrid_monitoring_proj\img\prod_env\node_exporter_on_EC2_sg.png)

---

## 📁 Repo Structure

```bash
prometheus_hybrid_monitoring_proj
│   README.md
│
├───docs
│       grafana_prometheus.txt
│
├───img
│   │   prometheus_hybrid_monitoring_architecture.gif
│   │   prometheus_hybrid_monitoring_architecture.png
│   │
│   └───prod_env
│           grafana_dashboard.png
│           monitoring_EC2_sg.png
│           node_exporter_on_EC2_sg.png
│           openvpn_sg.png
│           prometheus_UI_to_see_targets.png
│
└───scripts
        install_grafana.sh
        install_prometheus.sh
        install_prometheus_node_exporter.sh
```

---

## 🧪 Features

* ✅ Monitor CPU, Memory, Disk, Network (via Node Exporter)
* ✅ Pull-based metrics collection
* ✅ Grafana dashboards for system health
* ✅ OpenVPN client config from RHEL to AWS VPN server
* ✅ Nginx reverse proxy for metrics tunneling
* ✅ Shell scripts for quick setup

---

## 🚀 How to Run

### 1. 🔧 Install Prometheus & Grafana (Dev)

```bash
cd scripts/
./install_prometheus.sh
./install_grafana.sh
```

### 2. 🏷️ Start Node Exporter on Each Node

```bash
./install_node_exporter.sh
```

### 3. 🗂️ Configure Targets

Update `prometheus.yml` with your VM and EC2 IPs: (Dev Env)

```yaml
- targets:
  - "192.168.122.100:9100"   # RHEL VM private IP
  - "ec2-public-ip:9100"     # EC2 in dev
```

### 4. 🔐 Production: Secure Metric Access

* Configure **OpenVPN** on RHEL VM using `.ovpn` file
* Deploy **Nginx** on VPN server to reverse-proxy metrics:
    
    ```cat /etc/nginx/conf.d/node_exporter.conf
			server {
				listen 9100;

				location / {
					proxy_pass http://<RHEL_VPN_IP_tun0>:9100/;
				}
			}
  ```

### 5. 📊 Access Prometheus
Login: `http://localhost:9090` or your EC2 IP

![Prometheus UI](prometheus_hybrid_monitoring_proj\img\prod_env\prometheus_UI_to_see_targets.png)

### 6. 📊 Access Grafana

Login: `http://localhost:3000` or your EC2 IP
Default creds: `admin / admin`

Import custom dashboards from `grafana/dashboards/`
![Grafana Dashboard](prometheus_hybrid_monitoring_proj\img\prod_env\grafana_dashboard.png)

---

## 💬 Real-World Relevance

* 🔧 Mirrors hybrid infrastructure used in modern IT orgs
* 🔐 Prioritizes **security**, **scalability**, and **modular automation**
* 🤖 Shell scripting to eliminate manual errors
* 🧠 Hands-on understanding of networking, firewalls, and monitoring strategy
* The importance of the Grafana and prometheus tools to setup a centalized monioring system by combining the different cloud provider services and on-premises server

---

## 🧠 What I Learned

* Prometheus metric scraping in hybrid networks
* Secure tunneling with OpenVPN for on-prem/cloud integration
* Building scalable and secure monitoring pipelines
* Writing clean automation scripts for deployment
* Debugging the networking issues and firewall issues

---

## 📎 Connect with Me

📍 **LinkedIn**: \[https://www.linkedin.com/in/pavankumar-adapala/]
