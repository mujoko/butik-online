# Root composition per infrastructure.md

terraform {
  backend "s3" {}
}

locals {
  common_tags = var.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true # reduce cost for demo

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11" # supports recent EKS versions

  cluster_name                   = var.name
  cluster_version                = var.eks_cluster_version
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  enable_irsa = var.enable_irsa

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_group_defaults.instance_types
      desired_size   = var.node_group_defaults.desired_size
      min_size       = var.node_group_defaults.min_size
      max_size       = var.node_group_defaults.max_size
      capacity_type  = var.node_group_defaults.capacity_type
      subnet_ids     = module.vpc.private_subnets
      tags           = local.common_tags
    }
  }

  tags = local.common_tags
}

# Fetch and apply the upstream microservices-demo manifests
# Reference: https://github.com/GoogleCloudPlatform/microservices-demo
data "http" "microservices_demo" {
  url = "https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml"
}

data "kubectl_file_documents" "microservices_demo" {
  content = data.http.microservices_demo.response_body
}

# Give the cluster a few seconds to finalize API & auth readiness before applying manifests
resource "time_sleep" "wait_for_cluster_ready" {
  create_duration = "20s"
  depends_on      = [module.eks]
}

resource "kubectl_manifest" "microservices_demo" {
  for_each  = data.kubectl_file_documents.microservices_demo.manifests
  yaml_body = each.value

  # Ensure the EKS cluster is ready before applying manifests
  depends_on = [time_sleep.wait_for_cluster_ready]
}
