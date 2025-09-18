variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "name" {
  description = "Project/cluster name prefix"
  type        = string
  default     = "butik-online"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones to use"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "private_subnets" {
  description = "CIDRs for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
}

variable "public_subnets" {
  description = "CIDRs for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.96.0/20", "10.0.112.0/20", "10.0.128.0/20"]
}

variable "node_group_defaults" {
  description = "Defaults for managed node groups"
  type = object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
    capacity_type  = string
  })
  default = {
    instance_types = ["t3.small"]
    desired_size   = 2
    min_size       = 2
    max_size       = 4
    capacity_type  = "ON_DEMAND"
  }
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.33"
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (OIDC)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "butik-online-eks"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}
