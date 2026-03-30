
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


Deployment Instructions
Because these modules rely on outputs from one another (passed via local remote state), they must be applied in sequential order.

Navigate to each directory and run the standard Terraform workflow:

Network Foundation: ```bash
cd 00-vpc
terraform init && terraform apply
cd ..

Outbound Routing: ```bash
cd 10-nat
terraform init && terraform apply
cd ..

Data Layer: ```bash
cd 20-rds
terraform init && terraform apply
cd ..

Web Entry Point: ```bash
cd 30-alb
terraform init && terraform apply
cd ..

Compute Layer: ```bash
cd 40-ecs
terraform init && terraform apply
cd ..