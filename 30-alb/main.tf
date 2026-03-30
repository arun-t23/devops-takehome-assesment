data "terraform_remote_state" "vpc" {
  backend = "local"
  config  = { path = "../00-vpc/terraform.tfstate" }
}

# 1. Security Group for the ALB (Allow HTTP from everywhere)
resource "aws_security_group" "alb_sg" {
  name   = "roboshop-alb-sg"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. The Load Balancer itself
resource "aws_lb" "main" {
  name               = "roboshop-alb"
  internal           = false # This makes it internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}

# 3. Target Group (The "Waiting Room" for your containers)
resource "aws_lb_target_group" "app" {
  name        = "roboshop-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip" # Necessary for ECS Fargate

  health_check {
    path = "/" # Ensure your app has a root route for health checks
  }
}

# 4. Listener (Checks for traffic on port 80 and sends it to the Target Group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Outputs for the ECS layer to use
output "alb_dns_name" { value = aws_lb.main.dns_name }
output "target_group_arn" { value = aws_lb_target_group.app.arn }