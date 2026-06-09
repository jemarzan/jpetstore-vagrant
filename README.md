# JPetStore 6 — Automated 3-Tier Deployment with Vagrant

> A fully automated local infrastructure project provisioning the MyBatis JPetStore 6
> Java web application across a 3-tier architecture using Vagrant and shell scripting.

## Architecture
[ web01 · Nginx ]  →  [ app01 · Tomcat ]  →  [ db01 · MariaDB ]
192.168.56.11          192.168.56.12           192.168.56.15
Ubuntu 22.04           CentOS Stream 9         CentOS Stream 9

## Tech Stack

| Layer    | Technology          | VM    | IP              |
|----------|---------------------|-------|-----------------|
| Web / Proxy | Nginx (reverse proxy) | web01 | 192.168.56.11 |
| App      | Apache Tomcat 9 + Java 21 | app01 | 192.168.56.12 |
| Database | MariaDB (MySQL-compatible) | db01 | 192.168.56.15 |

## What This Project Demonstrates

- **Infrastructure as Code (IaC)** — entire stack defined in a single `Vagrantfile`
- **Multi-VM orchestration** — 3 VMs provisioned and networked automatically
- **Shell script provisioning** — idempotent bash scripts for each service tier
- **Database initialization** — MySQL-native schema creation and seed data import
- **App build automation** — Maven build + WAR deployment scripted end-to-end
- **Reverse proxy configuration** — Nginx forwarding traffic to Tomcat backend
- **Cross-distro setup** — Ubuntu (web) and CentOS Stream 9 (app + db) in the same stack

## Prerequisites

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/)
- vagrant-hostmanager plugin:
```bash
  vagrant plugin install vagrant-hostmanager
```

## Quick Start

```bash
# Clone the repo
git clone https://github.com/jemarzan/jpetstore-vagrant.git
cd jpetstore-vagrant

# Spin up all 3 VMs (takes ~10-15 min on first run)
vagrant up

# Access the app
open http://192.168.56.11/jpetstore
```

Bring up individual VMs in order if needed:
```bash
vagrant up db01    # database first
vagrant up app01   # app server second
vagrant up web01   # reverse proxy last
```

## Access

| URL | Description |
|-----|-------------|
| `http://192.168.56.11/jpetstore` | App via Nginx reverse proxy |
| `http://192.168.56.12:8080/jpetstore` | App direct via Tomcat |
| `http://192.168.56.11/health` | Nginx health check |

## Provisioning Scripts

| Script | VM | What it does |
|--------|----|--------------|
| `jpetstore-mysql.sh` | db01 | Installs MariaDB, creates DB/user, imports MySQL-native schema + seed data |
| `jpetstore-tomcat.sh` | app01 | Installs Java 21 + Tomcat 9 + Maven, patches app config to MySQL, builds and deploys WAR |
| `jpetstore-nginx.sh` | web01 | Installs Nginx, configures reverse proxy to app01, enables UFW firewall |

## Key Technical Decisions

- **MySQL-native schema**: The original JPetStore uses HSQLDB syntax incompatible with MariaDB. A clean MySQL schema was written from scratch to solve this.
- **Java 21 + Maven 3.9.16**: Required for the current master branch of JPetStore 6.
- **Firewalld disabled on app01**: Simplified setup; in production this would use proper firewall rules.
- **vagrant-hostmanager**: Automatically manages `/etc/hosts` on host and all guest VMs so services can refer to each other by hostname.

## Useful Vagrant Commands

```bash
vagrant status          # check VM states
vagrant ssh app01       # SSH into a VM
vagrant halt            # stop all VMs
vagrant destroy -f      # delete all VMs
vagrant provision app01 # re-run provisioning on one VM
```
## Screenshots

<img width="1827" height="207" alt="1" src="https://github.com/user-attachments/assets/b83632fe-1ce8-4106-b982-494545a72023" />
<img width="1832" height="815" alt="2" src="https://github.com/user-attachments/assets/f9df19c8-a423-4f0a-9578-4438c945c300" />
<img width="1835" height="606" alt="3" src="https://github.com/user-attachments/assets/34dd8f38-ad7a-4df1-a109-4d894bb99bee" />
<img width="1120" height="979" alt="4" src="https://github.com/user-attachments/assets/74e3a46c-d5ff-4d17-8507-a3815d88c3b4" />
<img width="970" height="563" alt="5" src="https://github.com/user-attachments/assets/7e1af400-6799-4a0d-8a09-719e418fd783" />

## Author

**[John Erimar Marzan]**
Junior DevOps Practitioner
https://github.com/jemarzan
