# Infrastructure Plan: Deploy Google Microservices Demo on AWS EKS 1.33 using Terraform Modules

## 1. Goals and Scope
- Deploy the Google Cloud Platform "microservices-demo" application to AWS on an EKS 1.33 cluster.
- Use Terraform with a modular architecture and reusable components.
- Apply the upstream Kubernetes manifests from:
  https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml
- Provide a repeatable workflow to provision, deploy, verify, and destroy.

## 2. High-Level Architecture
```mermaid
flowchart TD
  A[Terraform] --> B[VPC]
  A --> C[EKS Cluster (1.33)]
  C --> D[Managed Node Groups]
  C --> E[EKS Add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI]
  C --> F[IRSA OIDC Provider]
  C --> G[Helm/Kubernetes Providers]
  G --> H[AWS Load Balancer Controller]
  G --> I[Metrics Server]
  G --> J[Cluster Autoscaler]
  G --> K[Apply microservices-demo YAML]
  E --> L[Load Balancers (ALB/NLB)]
  K --> L
```

## 3. Terraform Project Structure
```
./
├── infrastructure.md  # This file
├── versions.tf        # Terraform, provider versions
├── providers.tf       # AWS, Kubernetes, Helm providers
├── main.tf            # Root composition calling modules
├── variables.tf       # Input variables
├── outputs.tf         # Useful outputs
├── terraform.tfvars.example  # Example values
├── modules/
│   ├── vpc/           # Wrapper using terraform-aws-modules/vpc
│   ├── eks/           # Wrapper using terraform-aws-modules/eks
│   ├── iam/           # IRSA roles & policies (if needed)
│   └── k8s-resources/ # Helm & raw YAML application
└── makefile (optional) # Helper commands
```

## 4. Key Module Selections
- VPC: terraform-aws-modules/vpc/aws (latest stable)
- EKS: terraform-aws-modules/eks/aws (supports EKS 1.33)
- Add-ons (two options):
  - Use built-in EKS module add-ons for VPC CNI, CoreDNS, kube-proxy, EBS CSI.
  - Use Helm/Kubernetes providers for other components (ALB Controller, Metrics Server, Cluster Autoscaler).
- Apply upstream YAML using the kubectl provider (gavinbunney/kubectl):
  - data http to fetch upstream YAML.
  - kubectl_file_documents to split multi-doc YAML.
  - kubectl_manifest to apply each document.

Note: If your organization prefers only official HashiCorp providers, we can pivot to Helm charts or the Kubernetes provider's manifest resource where feasible.

## 5. Versions and Compatibility
- Terraform: >= 1.6
- AWS Provider: ~> 5.x
- Kubernetes Provider: ~> 2.29
- Helm Provider: ~> 2.13
- Kubectl Provider: gavinbunney/kubectl ~> 1.14
- EKS Cluster Version: 1.33 (latest requested)
 - Target Region: ap-southeast-1 (Singapore)

## 6. Variables (Inputs)
- region (default ap-southeast-1)
- name (project/cluster name prefix)
- vpc_cidr (default 10.0.0.0/16)
- azs (e.g., ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"])
- private_subnets (CIDRs per AZ)
- public_subnets (CIDRs per AZ)
- node_group_defaults:
  - instance_types (e.g., ["t3.small"]) or Graviton ["t4g.small"]
  - desired_size/min_size/max_size (e.g., 2/2/4)
  - capacity_type (ON_DEMAND or SPOT)
- eks_cluster_version (default 1.33)
- enable_irsa (bool)
- tags (map)

## 7. Security and Governance
- IRSA: Enable OIDC and bind fine-grained IAM roles to service accounts as needed (e.g., ALB Controller, EBS CSI, Cluster Autoscaler).
- Control Plane Logging: Enable control plane logs to CloudWatch (api, audit, authenticator, controllerManager, scheduler).
- Secrets Management: Prefer external secrets/SSM Parameter Store or AWS Secrets Manager for app secrets (not used by demo, but recommended for real workloads).
- Network: Private subnets for nodes and load balancers when possible; public subnets only if needed for public ALBs.
- Encryption: Enable EBS volume encryption; optional EKS secrets encryption with KMS key.
- Access: Map IAM users/roles with aws-auth config; limit public endpoint access if desired.

## 8. Add-ons
- Core EKS add-ons via EKS module:
  - aws-ebs-csi-driver
  - vpc-cni
  - coredns
  - kube-proxy
- Additional:
  - AWS Load Balancer Controller (Helm)
  - Metrics Server (Helm)
  - Cluster Autoscaler (Helm) with appropriate IRSA

## 9. Application Deployment Strategy (Upstream YAML)
- Fetch upstream YAML:
  - data "http" to retrieve the raw file URL.
  - Split into multiple documents with kubectl_file_documents.
  - Apply each manifest via kubectl_manifest with for_each.
- Namespace: The upstream defines necessary namespaces; if not, create `hipster-shop` or default as per upstream definitions.
- Service Type: The demo includes a `frontend` Service of type LoadBalancer; ALB Controller will provision an ALB or use NLB based on annotations. Validate and adjust annotations if necessary.

## 10. Outputs
- VPC ID and Subnet IDs
- EKS cluster name, endpoint, and certificate data
- Kubeconfig path or merged kubeconfig data
- ALB DNS name or Service EXTERNAL-IP for `frontend`

## 11. Operational Workflow
1) terraform init
2) terraform plan
3) terraform apply -auto-approve
4) Update kubeconfig (data/exec or aws eks update-kubeconfig) if needed
5) Verify cluster and add-ons:
   - kubectl get nodes -o wide
   - kubectl get pods -A
   - kubectl get svc -A
6) Verify microservices-demo:
   - kubectl get pods -n hipster-shop (if namespace used in upstream) or default
   - Retrieve Service/ALB endpoint and open in browser

## 12. Validation/Smoke Tests
- Ensure all Deployments reach Ready state.
- Ensure LoadBalancer Service shows an external hostname.
- Hit the frontend URL and verify UI loads.

## 13. Costs and Footprint
- NAT Gateways (per AZ) can be significant; consider 1-2 NATs for non-prod.
- Node instance size/scale and EBS volumes drive costs.
- ALB hourly + LCU for public exposure.
- CloudWatch logs for control plane and add-ons.

## 14. Clean Up
- terraform destroy (may need to manually delete dangling LoadBalancer/TargetGroups if finalizers block; plan for Helm releases to uninstall in the right order).

## 15. Risks and Mitigations
- EKS version parity: If AWS region doesn’t yet support 1.33 GA, pin to latest supported (e.g., 1.31/1.32) and upgrade later.
- Provider drift: Keep providers pinned; run `terraform providers lock`.
- Upstream YAML changes: Pin to a specific commit or release URL for reproducibility.

## 16. Next Steps (Execution Plan)
- Step 1: Scaffold Terraform files and module wrappers.
- Step 2: Implement VPC module usage and variables.
- Step 3: Implement EKS module (cluster, node groups, add-ons, IRSA/OIDC).
- Step 4: Deploy Helm add-ons (ALB Controller, Metrics Server, Cluster Autoscaler).
- Step 5: Implement k8s-resources module to fetch and apply the upstream YAML.
- Step 6: Create terraform.tfvars.example and README with instructions.
- Step 7: Validate and iterate.

---
This document is the single source of truth for the deployment plan. Any changes should be proposed and updated here before implementation.
