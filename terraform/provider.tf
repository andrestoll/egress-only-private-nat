terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.36"
    }
  }

  backend "s3" {
    key = "tf-astoll/tgw-single-exit.tfstate"
  }

  required_version = ">= 1.3.3, < 2.0.0"
}

provider "aws" {
  region = "us-east-1"
}