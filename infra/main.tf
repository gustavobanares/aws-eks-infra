terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.38.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc"{
  source = "./modules/vpc"
  cluster_name = "tptech-cluster"
}