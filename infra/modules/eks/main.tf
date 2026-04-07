module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "~> 20.0"

    cluster_name                   = "tptech-cluster"
    cluster_version                = "1.32"
    cluster_endpoint_public_access = true
    enable_cluster_creator_admin_permissions = true

    eks_managed_node_groups = {
      default = {
        min_size       = 1
        max_size       = 3
        desired_size   = 1
        instance_types = ["t3.medium"]

        use_custom_launch_template = false
      }
    }

    vpc_id     = var.vpc_id
    subnet_ids = var.subnet_ids

    tags = {
      Environment = "dev"
      Terraform   = "true"
    }

     access_entries = {
    github_actions = {
      principal_arn = "arn:aws:iam::179942802757:role/github-actions-eks-deploy"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}