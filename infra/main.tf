terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
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

module "eks" {
  source = "./modules/eks"
  cluster_name = "tptech-cluster"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}