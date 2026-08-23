terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "voting-app-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # No private_subnets / NAT gateway — nodes go directly in public subnets
  # to avoid NAT gateway cost. See note below on the trade-off this makes.
  enable_nat_gateway = false
  map_public_ip_on_launch = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "voting-app-cluster"
  cluster_version = "1.35"

  # Explicitly enable public endpoint access — without this, kubectl from outside
  # the VPC (e.g. your own laptop) may resolve the cluster's private endpoint IP
  # and time out, since there's no network route from your machine into the VPC.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.micro"]
    }
  }
}