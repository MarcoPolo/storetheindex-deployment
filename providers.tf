terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  profile             = var.profile
  region              = "us-west-2"
  allowed_account_ids = ["407967248065"]
}
