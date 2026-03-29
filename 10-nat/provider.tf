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