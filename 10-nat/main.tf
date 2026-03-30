data "terraform_remote_state" "vpc" {
  backend = "local"
  config  = { path = "../00-vpc/terraform.tfstate" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]
  tags          = { Name = "roboshop-nat" }
}

# Route traffic from Private Subnet to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = data.terraform_remote_state.vpc.outputs.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private.id
}