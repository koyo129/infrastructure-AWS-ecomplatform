# infrastructure-AWS-ecomplatform
erraform-built AWS infra, focused on reliability, security, and ops documentation on E-commerce
# AWS Platform Infrastructure (Terraform)

## Overview
Steps i took was
1. The problem or the goal I want to achieve
2. Design ideas necessary components such as traffic flows, business needs, etc
3. 

This project simulates a small cloud infrastructure platform similar to what
large-scale services (e.g. e-commerce platforms) run on.

The focus is on:
- infrastructure design
- reliability and failure handling
- security boundaries
- operational thinking

## Scope & Trade-offs
This project focuses on high availability within a single AWS region using multiple Availability Zones.
Multi-region disaster recovery is intentionally out of scope, as it introduces additional complexity
(DNS failover, data consistency, operational overhead) and is typically addressed based on business requirements.

Application logic is intentionally kept simple.

---
## What This Project Demonstrates
- Infrastructure as Code using Terraform
- Automated Linux server configuration using user_data
- Basic cloud security concepts (security groups)
- Clear documentation and architecture explanation

## Architecture (Planned)
- VPC
- Public subnet (Load Balancer)
- Private subnet (EC2 instances)
- Application Load Balancer with health checks
- Two Linux EC2 instances running Nginx
- Security Groups with minimal access

> Architecture diagram will be added.

---

## Traffic Flow
1. User sends HTTP request
2. Request reaches the Application Load Balancer
3. ALB forwards traffic to healthy EC2 instances
4. EC2 returns a simple response page

---

## Reliability / Failure Handling
- ALB health checks detect unhealthy instances
- Traffic is automatically routed to healthy servers
- Service continues without user impact if one instance fails

---
## Security
- EC2 instances are protected by Security Groups
- Only HTTP traffic is allowed from the Load Balancer
- No direct SSH access from the internet

## Security Design
- Only ALB is internet-facing
- EC2 instances accept traffic only from ALB Security Group
- SSH access is restricted (or replaced with SSM)

---

## Infrastructure as Code
Infrastructure will be created using Terraform to ensure:
- reproducibility
- safe changes
- version control

---

## Future Improvements
- Add monitoring and alerts
- Introduce Auto Scaling
- Add HTTPS with ACM
- Create operational runbook
