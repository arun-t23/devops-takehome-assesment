terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.17.0"
    }
    ### I am doing this locally so not using S3 here, we can use S3 for remote state
  }
}

provider "aws" {
  # Configuration options
}



### For remote state use this provider

# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "6.17.0"
#     }
#   }
#   backend "s3" {
#     bucket       = "arun-roboshop-dev"
#     key          = "roboshop-dev-nat"
#     region       = "us-east-1"
#     use_lockfile = true
#     encrypt      = true
#   }

# }

# provider "aws" {
#   region = "us-east-1"
#   # Configuration options
# }