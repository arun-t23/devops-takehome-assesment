# Read data from the 00-vpc folder
data "terraform_remote_state" "vpc" {
  backend = "local" # Change to 's3' if using remote state
  config = {
    path = "../00-vpc/terraform.tfstate"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  # We get the subnet ID from the VPC folder's output!
  subnet_id     = data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]

  tags = { Name = "roboshop-nat" }
}