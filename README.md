# AWS Multi-AZ Web Infrastructure (Terraform)

## Overview

This project is about provisioning high available web infrastructure on AWS using Terraform.
It includes:

- Custom VPC
- Public & Private subnets (2 Availability Zones)
- Internet Gateway
- NAT Gateways (1 per AZ)
- Application Load Balancer (ALB)
- Auto Scaling Group (ASG)
- Amazon Linux 2023 EC2 instances running nginx
- Infrastructure defined as code


This project demonstrates:

- Infrastructure as Code (IaC)
- High Availability design
- Secure network architecture
- Auto-healing compute layer
- Production-style ALB + ASG architecture

---

#  Architecture

### Traffic Flow

```
User
  ↓
Internet Gateway
  ↓
Application Load Balancer (Public Subnets)
  ↓
Auto Scaling Group (Private Subnets)
  ↓
nginx running on Amazon Linux
```

### Outbound Flow (for updates)

```
EC2 (Private)
  ↓
NAT Gateway (Public Subnet)
  ↓
Internet Gateway
  ↓
Internet
```

---

# High Availability Design

- Infrastructure has 2 Availability Zones
- 2 Public Subnets
- 2 Private Subnets
- 2 NAT Gateways (one per AZ)
- Auto Scaling Group maintains minimum 2 instances
- ALB distributes traffic across AZs

Example: If one AZ fails
- Traffic continues to the healthy AZ
- ASG replaces unhealthy instances automatically

---

# Security Design

- EC2 instances are deployed in private subnets
- No public IP assigned to EC2
- EC2 Security Group only allows traffic from ALB Security Group
- ALB for public-facing component

Prevents direct internet access to backend servers.

---

# Services and Tools Used

- Terraform
- AWS VPC
- AWS ALB
- AWS Auto Scaling Group
- AWS NAT Gateway
- Amazon Linux 2023
- nginx

---

# Infrastructure Components

## VPC 
- Custom CIDR block
- DNS enabled

## Public Subnets
- Host ALB and NAT Gateways
- Route to Internet Gateway

## Private Subnets
- Host EC2 instances
- Route outbound traffic through NAT Gateway

## NAT Gateways
- One per AZ
- Removes single point of failure

## Load Balancer
- Public-facing
- Listens on port 80
- Performs health checks

## Auto Scaling Group
- Desired capacity: 2
- Min size: 2
- Max size: 4
- Replaces unhealthy instances automatically

---

# EC2 Configuration

Instances run Amazon Linux 2023.

On boot, the following happens automatically:

- OS updates
- nginx installation
- Custom HTML page creation
- nginx service enabled and started

Example `user_data.sh`:

```bash
#!/bin/bash
dnf update -y
dnf install -y nginx

cat <<EOF > /usr/share/nginx/html/index.html
<h1>Hello from Linux EC2</h1>
<p>Instance: $(hostname)</p>
<p>Deployed via Terraform + Auto Scaling</p>
EOF

systemctl enable nginx
systemctl start nginx
```

Refreshing the page shows different hostnames, proving load balancing works.

---

# How to Deploy

### 1. Initialize Terraform

```
terraform init
```

### 2. Review Execution Plan

```
terraform plan
```

### 3. Apply Infrastructure

```
terraform apply
```

### 4. Access the Website

After deployment, Terraform outputs:

```
alb_dns_name = xxxxx.elb.amazonaws.com
```

Open this in your browser.

---

# What This Project Demonstrates

- AWS networking fundamentals
- Proper separation of public and private resources
- High availability architecture
- Removal of single points of failure
- Infrastructure automation best practices
- Secure backend design (no public EC2 exposure)

---

# Future Improvements

- Add HTTPS (ACM + Route53)
- Add Auto Scaling policies based on CPU
- Add CI/CD pipeline for Terraform
- Add WAF for enhanced security
- Convert to reusable Terraform modules
- S3 for storing logs 

---

# Learning Outcome

This project helped deepen understanding of:

- VPC routing behavior
- NAT Gateway architecture
- ALB target groups & health checks
- Auto Scaling self-healing behavior
- Linux bootstrapping with user_data
- Infrastructure as Code best practices

---

# Author

Just a curious, motivated student who built as a cloud infrastructure learning project focused on AWS and Terraform. If you have any comments, improvements please messgae or leave a comment!!!!!
