# Multi-Region Active-Passive Cloud Failover Engine

## Project Overview
This project is a highly available, zero-downtime cloud architecture designed to eliminate the Single Point of Failure (SPOF) during data center outages. Built entirely from the ground up, it demonstrates a modern GitOps workflow for provisioning, configuring, and deploying a multi-continent disaster recovery web engine.

By leveraging intelligent routing and continuous integration, the infrastructure actively monitors origin health and seamlessly routes traffic to a standby node in the event of a primary failure—requiring zero human intervention.

## Architecture
Architecture.png

**Traffic Flow:**
`User Browser` ➔ `HTTPS (Port 443)` ➔ `AWS CloudFront (Global Edge Network)` ➔ `HTTP (Port 80)` ➔ `Active EC2 Origin (Mumbai)` 
*(Fallback routes automatically to Standby EC2 Origin in Singapore)*

## Tech Stack & Tools
* **Cloud Provider:** AWS (CloudFront, EC2, IAM)
* **Infrastructure as Code (IaC):** Terraform
* **Configuration Management:** Ansible Core
* **CI/CD Pipeline:** GitHub Actions
* **Operating System:** Linux (Ubuntu Focal)
* **Web Server:** Apache2
* **Version Control:** Git / GitHub

## Core Workflow & Automation
1. **Infrastructure Provisioning:** Terraform handles the declarative setup of the AWS VPC, Security Groups (allowing Port 80 for CloudFront and Port 22 for GitHub Actions), and the EC2 instances across the `ap-south-1` and `ap-southeast-1` regions.
2. **Configuration Management:** Ansible playbooks execute headless deployments, mapping dynamic variables using `{{ inventory_hostname }}` to visually stamp the server's unique IP address onto the frontend UI for real-time failover verification.
3. **Continuous Deployment (GitOps):** The GitHub Actions pipeline is event-driven (`on: push` to `main`). Ephemeral Linux runners securely extract vaulted SSH keys and execute the Ansible configurations with strict headless flags (`StrictHostKeyChecking=no`), ensuring a true zero-touch deployment.

## Engineering Hurdles Overcome
During the build process, several real-world environment and pathing challenges were successfully resolved:
* **Package Manager Discrepancies:** Initial configurations targeted standard CentOS package managers (`httpd`). This triggered pipeline failures on the target Ubuntu instances. The deployment logic was debugged and refactored to specifically target the `apache2` package for Ubuntu compatibility.
* **Absolute Pathing Fixes:** Corrected a critical payload delivery error by moving from relative pathing (`var/www/html`) to the strict absolute path (`/var/www/html/index.html`), ensuring the HTML engine deployed accurately regardless of the CI/CD runner's default execution directory.
* **Race Conditions:** Managed standard EC2 boot-time delays by tuning pipeline execution speeds, ensuring SSH listeners on Port 22 were fully awake before Ansible attempted the handshake.

## Live Disaster Recovery Demonstration
To test the failover engine:
1. Navigate to the global CloudFront URL.
2. The UI will display the active IP (Mumbai Node).
3. Manually stop the primary instance via the AWS EC2 Console.
4. Refresh the CloudFront URL using a cache-buster parameter (e.g., `/?nocache=1`).
5. Traffic is instantly re-routed to the standby Singapore node, verified by the updated IP on the screen.

## Repository Structure
```text
├── .github/workflows/
│   └── deploy.yml          # GitHub Actions CI/CD pipeline definition
├── main.tf                 # Terraform infrastructure blueprint
├── inventory.ini           # Dynamic IP routing for configuration
├── playbook.yml            # Ansible automation instructions
└── README.md               # Project documentation
