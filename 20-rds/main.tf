data "terraform_remote_state" "vpc" {
  backend = "local"
  config  = { path = "../00-vpc/terraform.tfstate" }
}

# 1. DB Subnet Group: Tells RDS which subnets to use
resource "aws_db_subnet_group" "main" {
  name       = "roboshop-db-group"
  subnet_ids = data.terraform_remote_state.vpc.outputs.db_subnet_ids
  tags       = { Name = "roboshop-db-group" }
}

# 2. Security Group: Only allows the Backend to talk to the DB
resource "aws_security_group" "rds_sg" {
  name   = "roboshop-rds-sg"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restricted to internal VPC traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. The Scalable RDS Instance
resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  max_allocated_storage  = 100 # This handles the "hundreds of thousands of rows" requirement
  db_name                = "roboshop"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro" 
  username               = "dbadmin"
  password               = var.root_password # Use AWS Secrets Manager in real production
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  multi_az               = true  # Requirement: Zero Downtime
  skip_final_snapshot    = true
}