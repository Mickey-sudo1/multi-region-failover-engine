# Multi-Region Active-Passive Cloud Failover Engine

A multi-region AWS setup that automatically switches traffic from a primary EC2 server to a standby server when the primary server becomes unavailable.

I built this project to understand how cloud infrastructure can be designed to handle a regional or server-level failure without requiring someone to manually deploy another server during an outage.

The infrastructure is provisioned using **Terraform**, configured with **Ansible**, and deployed through **GitHub Actions**. AWS CloudFront is used as the global entry point, with EC2 instances running in Mumbai and Singapore.

---

## What This Project Does

The project runs the same web application on two EC2 instances:

* **Mumbai (`ap-south-1`)** — Primary / Active server
* **Singapore (`ap-southeast-1`)** — Secondary / Standby server

Under normal conditions, traffic is served by the Mumbai instance.

If the primary instance becomes unavailable, CloudFront can route requests to the Singapore instance.

Each server displays its own public IP address on the webpage. This makes it easy to see which server is currently handling the request during a failover test.

The entire infrastructure and server configuration are managed as code, so the environment can be recreated without manually configuring each server.

---

## Architecture

![Architecture Diagram](Architecture.png)

### Traffic Flow

```text
                         User
                           |
                           | HTTPS :443
                           v
                  +-------------------+
                  |   AWS CloudFront  |
                  |   Global Network  |
                  +---------+---------+
                            |
                            | HTTP :80
                            v
                 +---------------------+
                 |   Mumbai EC2        |
                 |   ACTIVE / PRIMARY  |
                 +----------+----------+
                            |
                     Primary failure
                            |
                            v
                 +---------------------+
                 |   Singapore EC2     |
                 |  STANDBY / BACKUP    |
                 +---------------------+
```

### AWS Regions

| Region           | Purpose              |
| ---------------- | -------------------- |
| `ap-south-1`     | Primary EC2 instance |
| `ap-southeast-1` | Standby EC2 instance |

---

## Technology Stack

| Technology         | Purpose                                         |
| ------------------ | ----------------------------------------------- |
| **AWS EC2**        | Hosts the web servers                           |
| **AWS CloudFront** | Global traffic entry point and origin failover  |
| **AWS IAM**        | Access control for AWS resources                |
| **Terraform**      | Infrastructure provisioning                     |
| **Ansible**        | Server configuration and application deployment |
| **GitHub Actions** | CI/CD automation                                |
| **Ubuntu**         | Operating system for EC2                        |
| **Apache2**        | Web server                                      |
| **Git / GitHub**   | Version control and source management           |

---

## How It Works

### 1. Infrastructure Provisioning

Terraform provisions the required AWS infrastructure.

This includes:

* EC2 instances
* VPC/network configuration
* Security groups
* Required AWS permissions
* CloudFront configuration
* Resources in both AWS regions

The goal is to keep the infrastructure reproducible rather than creating everything manually through the AWS Console.

---

### 2. Server Configuration with Ansible

After the EC2 instances are available, Ansible connects to them over SSH and configures the servers.

The playbook installs and configures Apache2 and deploys the HTML page.

The page dynamically displays information about the server so that I can identify which EC2 instance is serving the request.

For example:

```text
Server: Mumbai
IP: <Mumbai instance IP>
```

or

```text
Server: Singapore
IP: <Singapore instance IP>
```

This makes the failover behavior visible during testing.

---

### 3. CI/CD with GitHub Actions

The project uses GitHub Actions to automate deployment.

The workflow is triggered when changes are pushed to the `main` branch.

The pipeline:

1. Checks out the repository.
2. Sets up the required environment.
3. Retrieves the required SSH credentials securely.
4. Connects to the EC2 instances.
5. Runs the Ansible playbook.
6. Deploys the latest configuration and web files.

This means changes can be pushed to GitHub and deployed without manually SSHing into every server.

---

## Disaster Recovery / Failover Test

I tested the setup by intentionally taking the primary server offline.

### Test Procedure

1. Open the CloudFront URL.
2. Confirm that the webpage is being served by the Mumbai EC2 instance.
3. Stop the Mumbai EC2 instance from the AWS Console.
4. Wait for the origin health status to update.
5. Send a new request to the CloudFront distribution.
6. CloudFront routes the request to the Singapore standby instance.
7. The webpage now displays the Singapore server's IP address.

The change in the displayed IP makes it easy to verify that the request is being served by the backup server.

> **Note:** CloudFront caching and health-check behavior can affect how quickly a failover becomes visible. For testing, a cache-busting query parameter can be used when appropriate.

Example:

```text
/?nocache=1
```

---

## Engineering Challenges

This project also involved several problems that I had to debug while building the automation.

### Ubuntu vs. CentOS Package Management

The initial Ansible configuration used the `httpd` package, which is commonly associated with CentOS/RHEL systems.

The EC2 instances were running Ubuntu, so the deployment failed.

I updated the playbook to use the correct Ubuntu package:

```text
apache2
```

This was a useful reminder that automation needs to account for the actual target operating system instead of assuming that package names and commands are universal.

---

### Incorrect File Path

One of the deployment steps initially used a relative path:

```text
var/www/html/index.html
```

This caused the deployment to fail because the path was not being interpreted as the intended system directory.

I corrected it to the absolute path:

```text
/var/www/html/index.html
```

This ensured that Ansible consistently deployed the webpage to Apache's document root.

---

### EC2 Boot / SSH Timing

Another issue occurred when GitHub Actions attempted to connect to a newly created EC2 instance before the SSH service was ready.

The instance could be running while the SSH service was still starting.

I adjusted the deployment process to account for this startup delay before allowing Ansible to connect.

This helped avoid intermittent SSH connection failures during automated deployments.

---

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD workflow
│
├── main.tf                     # Terraform infrastructure
├── inventory.ini               # Ansible inventory
├── playbook.yml                # Ansible configuration
├── Architecture.png            # Architecture diagram
└── README.md                   # Project documentation
```

---

## Deployment Flow

The overall workflow looks like this:

```text
Developer
    |
    | git push
    v
GitHub Repository
    |
    v
GitHub Actions
    |
    | Terraform
    v
AWS Infrastructure
    |
    | Ansible
    v
EC2 Instances
    |
    v
Apache Web Server
    |
    v
CloudFront
    |
    v
Users
```

---

## Getting Started

### Prerequisites

Before deploying the project, you will need:

* An AWS account
* AWS CLI
* Terraform
* Ansible
* Git
* An SSH key pair
* A GitHub repository
* Appropriate AWS IAM permissions

---

### Clone the Repository

```bash
git clone <repository-url>

cd <repository-directory>
```

---

### Configure AWS Credentials

Configure the AWS CLI with an IAM user that has the permissions required by the Terraform configuration.

```bash
aws configure
```

Verify the configuration:

```bash
aws sts get-caller-identity
```

---

### Generate SSH Keys

If you don't already have an SSH key pair:

```bash
ssh-keygen -t ed25519
```

The public key can be used for EC2 access, while the private key should be stored securely.

**Never commit your private key to GitHub.**

---

### Initialize Terraform

```bash
terraform init
```

Review the infrastructure:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

---

### Configure Ansible

Update `inventory.ini` with the appropriate EC2 IP addresses or host information.

Then run:

```bash
ansible-playbook -i inventory.ini playbook.yml
```

---

## Security Notes

This project is intended as a learning and demonstration project, so some production-level security improvements would still be required.

In particular:

* Do not commit AWS access keys to GitHub.
* Do not commit private SSH keys.
* Store GitHub Actions secrets using GitHub Secrets.
* Follow the principle of least privilege when creating IAM policies.
* Restrict security-group rules as much as possible.
* Avoid exposing SSH (`port 22`) to the entire internet in a production environment.
* Use HTTPS between CloudFront and the origins where appropriate.
* Consider using AWS Systems Manager instead of direct SSH access for production environments.

---

## What I Learned

Building this project gave me practical experience with several areas of cloud and DevOps engineering:

* Provisioning infrastructure using Terraform
* Managing multiple AWS regions
* Working with EC2 and security groups
* Configuring Linux servers with Ansible
* Building a GitHub Actions deployment pipeline
* Debugging CI/CD failures
* Understanding CloudFront origin failover
* Working with SSH-based automation
* Troubleshooting cloud networking and deployment issues
* Thinking about disaster recovery and availability

More importantly, I learned that infrastructure automation involves a lot of debugging between different layers — Terraform, AWS, Linux, SSH, Ansible and CI/CD — rather than simply writing configuration files and expecting everything to work on the first attempt.

---

## Limitations

This project demonstrates the core idea of multi-region failover, but it is not intended to represent a complete production disaster-recovery platform.

Some areas that could be improved include:

* Automated application health monitoring
* Infrastructure state management using a remote Terraform backend
* More restrictive IAM policies
* Private EC2 instances behind load balancers
* HTTPS communication between CloudFront and the origins
* Centralized logging and monitoring
* Automated alerting
* Database replication across regions
* Automated infrastructure recovery
* More comprehensive failure testing
* DNS-based failover for scenarios where CloudFront is not suitable

---

## Future Improvements

Some improvements I would like to make in a future version include:

1. Add centralized monitoring using Amazon CloudWatch.
2. Add automated alerts when the primary region becomes unhealthy.
3. Use AWS Systems Manager instead of SSH-based configuration where possible.
4. Move Terraform state to an S3 backend with state locking.
5. Add automated infrastructure testing.
6. Improve IAM policies using least-privilege permissions.
7. Add HTTPS communication throughout the architecture.
8. Add a database layer with cross-region replication.
9. Expand the setup into a more production-like active-passive disaster recovery architecture.
10. Add a complete automated recovery process rather than only traffic failover.

---

## Project Status

**Status:** Completed as a learning / portfolio project.

The current implementation demonstrates:

* Multi-region EC2 infrastructure
* Infrastructure as Code with Terraform
* Configuration management with Ansible
* GitHub Actions CI/CD
* CloudFront-based traffic routing
* Primary-to-standby failover testing

---

## Author

**Michael Antony**

DevOps / Cloud Engineering Enthusiast

* GitHub: `<your-github-link>`
* LinkedIn: `<your-linkedin-link>`

---

## Disclaimer

This project was built as a hands-on learning project to understand cloud infrastructure, automation, CI/CD and disaster recovery concepts.

It is not intended to be used as-is for a production workload without additional security, monitoring, testing and reliability improvements.
