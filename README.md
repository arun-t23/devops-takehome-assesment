
# AWS Terraform Deployment

A modular Terraform configuration for deploying a containerized application on AWS, with a complete networking, database, load balancing, and container orchestration stack.

## Architecture Overview

This infrastructure is organized into 5 sequential modules that build upon each other:

1. **VPC & Networking** — Foundation with subnets across multiple availability zones
2. **NAT Gateway** — Secure outbound routing for private subnets
3. **RDS Database** — Multi-AZ PostgreSQL for data persistence
4. **Application Load Balancer** — HTTP/HTTPS entry point with target routing
5. **ECS Fargate** — Containerized application deployment and scaling

## Project Structure

```text
├── 00-vpc/                 # Network foundation (VPC, Subnets, IGW, Route Tables)
├── 10-nat/                 # Predictable outbound routing (NAT Gateway, Elastic IP)
├── 20-rds/                 # Data layer (PostgreSQL Multi-AZ, Subnet Groups)
├── 30-alb/                 # Web entry point (Application Load Balancer, Target Groups)
├── 40-ecs/                 # Compute layer (ECS Cluster, Fargate Services, Task Defs)
├── Dockerfile              # Container blueprint for the React/Python application
├── roboshop-infra.drawio   # Editable architecture diagram
└── README.md               # Project documentation
```

## Prerequisites

- AWS account with appropriate credentials configured
- Terraform >= 1.0
- AWS CLI (optional, for manual verification)
- Docker (for building/testing container images locally)

## Deployment Instructions

**Important:** These modules depend on outputs from previous stages. Deploy them in sequential order.

### Step 1: Network Foundation (00-vpc)
```bash
cd 00-vpc
terraform init
terraform apply
cd ..
```

### Step 2: Outbound Routing (10-nat)
```bash
cd 10-nat
terraform init
terraform apply
cd ..
```

### Step 3: Data Layer (20-rds)
```bash
cd 20-rds
terraform init
terraform apply
cd ..
```

### Step 4: Load Balancer (30-alb)
```bash
cd 30-alb
terraform init
terraform apply
cd ..
```

### Step 5: Application Layer (40-ecs)
```bash
cd 40-ecs
terraform init
terraform apply
cd ..
```

## Cleanup

To destroy all resources in reverse order:

```bash
for dir in 40-ecs 30-alb 20-rds 10-nat 00-vpc; do
  cd $dir
  terraform destroy
  cd ..
done
```

## Notes

- State is managed locally. For production, configure remote state (S3 + DynamoDB).
- Review `terraform plan` output before applying, especially for database changes.
- Outputs from each module are passed to dependent modules via Terraform references.