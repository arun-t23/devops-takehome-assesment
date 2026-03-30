# Architecture and Migration Plan
**DevOps Take-Home Assignment**

## 1. Overview and Goals
Right now, the infrastructure is using manual SSH deployments to a single EC2 server with no automated scaling. This causes the application to crash due to swap thrashing and the database to slow down when load is high. 

My plan is to move the infrastructure to a modern, containerized setup using **AWS ECS Fargate** and **Terraform**. This provides zero downtime, automatic scaling, and a much more secure network.

## 2. The New Architecture 
Here is how I designed the new system to fix the current problems:

**A. Network and Security**
* I designed a 3-Tier VPC (Virtual Private Cloud). 
* **Public Subnet:** Only the Application Load Balancer (ALB) lives here to take traffic from the internet.
* **Private Subnet:** The React and Python apps live here in Docker containers. They are safe from the open internet.
* **Database Subnet:** The PostgreSQL database lives here, completely isolated.
* **Fixed IP for Partners:** I added a **NAT Gateway** with an Elastic IP. All outbound traffic from our app goes through this single IP. This solves the requirement for partner API whitelisting.

**B. Compute and Load Spikes**
* We will stop using manual EC2 VMs. We will put the Python and React apps into Docker containers and run them on **AWS ECS Fargate**.
* Fargate is "serverless" compute. We just tell AWS how much RAM and CPU we need, and AWS runs it. 
* **Fixing Swap Thrashing:** Fargate lets us put hard memory limits on containers. If a task uses too much memory, Fargate just kills that one container and starts a fresh one immediately. The whole server will not crash anymore. We will also set Auto-Scaling to add more containers when CPU goes over 70%.

**C. Database Scalability**
To fix the high database load when writing hundreds of thousands of rows, we will do this:
1. **Multi-AZ and Auto-Scaling:** We will turn on Multi-AZ for the RDS database so it never goes down. We also turn on storage auto-scaling so the disk grows automatically when large data comes in.
2. **Read Replicas:** We can add a Read Replica to handle all the "read" traffic (like business analytics), so the main database only handles "writes".
3. **Queue System (Future):** Later, we will add Amazon SQS. When the Python app needs to write heavy rows, it will drop a message in the queue instead of locking the database. A background worker will read the queue and write to the database slowly and safely.

## 3. Why I chose this approach
**Why ECS Fargate instead of Kubernetes (EKS)?**
Kubernetes is a great tool, but it is very complex and expensive for a small startup. The EKS control plane alone costs extra money every month. ECS Fargate is much easier for a small team to manage. It removes the need to patch servers and integrates perfectly with AWS Load Balancers and CloudWatch.

## 4. Migration Plan (Zero Downtime)
We will use a "Blue/Green" style migration to make sure users don't experience any downtime.
1. **Build:** Run the Terraform code to build the new VPC, ECS cluster, and Load Balancer next to the old system.
2. **Data:** Connect the new ECS app to the existing database (or a synced copy of it).
3. **Test:** Use the new Load Balancer URL to test the app internally and make sure it works perfectly.
4. **Shift Traffic:** Change the DNS (Route 53) to send 10% of user traffic to the new ECS setup. We watch the logs for errors.
5. **Complete:** If everything is good, we shift 100% of traffic to the new setup and turn off the old EC2 servers.

## 5. Timeline and Priorities

**First 3 Months (Immediate Fixes):**
* Finish writing the Infrastructure as Code (Terraform) for the VPC, ECS, and RDS.
* Put the Python and React apps into Docker (`Dockerfile`).
* Setup basic CloudWatch alarms to send an email or Slack message if memory gets too high.

**6 to 12 Months (Making it better):**
* Build a full CI/CD pipeline (like GitHub Actions) to build and deploy the code automatically when developers push to the `main` branch.
* Add Amazon SQS for asynchronous database writes.
* Move database passwords out of the code and into AWS Secrets Manager.
* Add OpenTelemetry (OTel) to trace which specific database queries are taking too long.

## 6. Architecture Diagram


## Project Structure
The Infrastructure-as-Code (IaC) is strictly modularized to separate concerns, making it easier for multiple team members to collaborate and limiting the impact of configuration errors.

```text
├── 00-vpc/                 # Network foundation (VPC, Subnets, IGW, Route Tables)
├── 10-nat/                 # Predictable outbound routing (NAT Gateway, Elastic IP)
├── 20-rds/                 # Data layer (PostgreSQL Multi-AZ, Subnet Groups)
├── 30-alb/                 # Web entry point (Application Load Balancer, Target Groups)
├── 40-ecs/                 # Compute layer (ECS Cluster, Fargate Services, Task Defs)
├── Dockerfile              # Container blueprint for the React/Python application
├── roboshop-infra.drawio   # Editable architecture diagram
└── README.md               # Project documentation