# butik-online Infrastructure (AWS EKS + Microservices Demo)

This repository provisions an AWS EKS cluster and deploys the Google "microservices-demo" (a.k.a. Online Boutique) using Terraform.

## Table of Contents
- Prerequisites
- Project structure
- Quick start
- Deploy the microservices demo
- Get the frontend URL
- Destroy resources (cost control)
- Troubleshooting

## Prerequisites
- Terraform 1.5.x or newer
- AWS CLI v2 configured with an account/credentials
- kubectl installed and on PATH
- Helm v3 installed and on PATH

Region and naming defaults are set to `ap-southeast-1` and cluster name `butik-online`. You can change these via variables.

## Project structure
```
./
├── infrastructure.md           # Architecture/plan notes
├── versions.tf                 # Terraform core + provider versions
├── providers.tf                # AWS + Kubernetes + Helm + Kubectl providers wired to EKS
├── main.tf                     # VPC, EKS, microservices demo
├── variables.tf                # All inputs
├── outputs.tf                  # Useful outputs (VPC/EKS)
└── terraform.tfvars.example    # Example inputs you can copy (gitignored if named terraform.tfvars)
```

## Quick start
1) Initialize providers and modules
```
terraform init
```

2) Review plan
```
terraform plan -out=tfplan
```

3) Apply (provisions VPC, EKS, node groups, add-ons, and deploys microservices-demo YAML)
```
terraform apply "tfplan"
```

4) Configure local kubeconfig for kubectl
```
aws eks update-kubeconfig --region ap-southeast-1 --name butik-online
```

## Deploy the microservices demo
This repo fetches and applies the upstream manifests automatically during `terraform apply` using the `kubectl` provider. After apply finishes:

- Verify cluster and workloads
```
kubectl get nodes -o wide
kubectl get pods -A
```

## Get the frontend URL
The demo exposes a `Service` of type `LoadBalancer` named `frontend-external` in the `default` namespace.

- List services and copy the EXTERNAL-IP hostname:
```
kubectl get svc -A
```

- Or print just the hostname:
```
kubectl get svc frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open the resulting `http://<elb-hostname>` in your browser.

 

## Destroy resources (cost control)
To avoid ongoing costs, destroy the stack when not in use:
```
terraform destroy -auto-approve
```

Note: Load balancers, EBS volumes, and CloudWatch logs are billed while running.

## Troubleshooting
- EKS version vs AMI type:
  - For EKS 1.33+, the node group `ami_type` is set to `AL2023_x86_64_STANDARD` (Amazon Linux 2023). AL2 is not supported for 1.33.
- Kubernetes auth immediately after cluster creation:
  - The config enables `enable_cluster_creator_admin_permissions = true` and adds a short wait before applying manifests.
  - If you see auth errors, retry after 20–60 seconds or run `aws eks update-kubeconfig` again.
- Microservices demo not accessible:
  - `kubectl get svc -A` and look for `frontend-external` with an external hostname. It may take a couple minutes to provision.

## Variables (commonly used)
See `variables.tf` for the full list. Common ones:
- `region` (default `ap-southeast-1`)
- `name` (cluster name, default `butik-online`)
- `azs`, `private_subnets`, `public_subnets`
- Node group sizing under `node_group_defaults`
- `eks_cluster_version` (default `1.33`)

## Outputs
- `eks_cluster_name`, `eks_cluster_endpoint`, `eks_cluster_certificate_authority_data`
- `vpc_id`, `private_subnet_ids`, `public_subnet_ids`

---
If you want a Makefile for one-command workflows (init/plan/apply/destroy, kubeconfig, frontend URL), let me know and I’ll add it.
