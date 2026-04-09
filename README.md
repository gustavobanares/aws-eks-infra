# AWS EKS Infrastructure & Deployment

End-to-end DevOps project: provision AWS infrastructure with Terraform, deploy a containerized app to Kubernetes, and automate everything with GitHub Actions using OIDC authentication.

## Architecture

```
GitHub Actions (OIDC)
       │
       ▼
  AWS IAM Role
       │
       ├── Terraform ──► S3 (tfstate)
       │                  VPC + EKS
       │
       └── kubectl ──► EKS Cluster
                            │
                       Deployment (2 pods)
                            │
                       Service (LoadBalancer)
                            │
                       Internet
```

## Project Structure

```
.
├── app/
│   ├── Dockerfile           # NGINX image built for linux/amd64
│   ├── index.html           # Application page
│   └── k8s/
│       ├── deployment.yaml  # 2 replicas, rolling update strategy
│       └── service.yaml     # LoadBalancer exposing port 80
├── infra/
│   ├── backend.tf           # S3 remote state
│   ├── main.tf              # Provider + module wiring
│   ├── variables.tf         # aws_account_id, sso_admin_role_arn
│   ├── iam.tf               # OIDC provider + GitHub Actions role
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/             # VPC, subnets, IGW, route tables
│       └── eks/             # EKS cluster + node group + access entries
└── .github/workflows/
    ├── ci.yml               # Build and push Docker image
    └── terraform.yml        # Terraform plan on PR, apply on merge
```

## Infrastructure (Terraform)

### VPC

- CIDR: `10.0.0.0/16`
- 2 public subnets across `us-east-1a` and `us-east-1b`
- Internet Gateway + Route Table for public access
- `enable_dns_hostnames = true` — required for EKS nodes to register
- EKS subnet tags (`kubernetes.io/cluster` and `kubernetes.io/role/elb`) for load balancer discovery

### EKS

- Cluster: `tptech-cluster`, Kubernetes `1.32`
- Managed node group: `t3.medium`, min=1, max=3, desired=2
- Public endpoint enabled so nodes can reach the control plane
- Access entries managed declaratively (no `aws-auth` ConfigMap):
  - SSO admin role — full cluster access
  - GitHub Actions role — full cluster access for deployments

### IAM

- **OIDC Provider** — trust relationship between AWS and `token.actions.githubusercontent.com`
- **Role** `github-actions-eks-deploy` — assumed by GitHub Actions via OIDC (no Access Keys)
- **Policy** — `eks:DescribeCluster`, `eks:ListClusters`, S3 state access, EC2, IAM, KMS, CloudWatch

### Remote State

Terraform state is stored in S3 bucket `tptech-onboarding-tfstate` with versioning enabled. The bucket must be created manually before running `terraform init`.

## Application (Kubernetes)

### Deployment

- Image: `gustavobanares/tptech-nginx` (built for `linux/amd64`)
- 2 replicas with rolling update strategy (`maxSurge: 20%`, `maxUnavailable: 10%`)
- Resource limits: 400m CPU, 256Mi memory

### Service

- Type: `LoadBalancer` — provisions an AWS ELB automatically
- Port 80 → container port 80

## CI/CD (GitHub Actions)

### `ci.yml` — App Deployment

Triggers on push to `main`. Authenticates to AWS via OIDC, updates kubeconfig, and applies Kubernetes manifests.

### `terraform.yml` — Infrastructure

Triggers only when files inside `infra/` change:
- **Pull Request** → runs `terraform plan`
- **Merge to main** → runs `terraform apply`

## Prerequisites

- AWS CLI configured with SSO profile
- Terraform >= 1.5
- kubectl
- Docker with buildx support
- S3 bucket for tfstate created manually

## Setup

### 1. Configure variables

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
```

Fill in `infra/terraform.tfvars`:

```hcl
aws_account_id     = "your-aws-account-id"
sso_admin_role_arn = "arn:aws:iam::your-account-id:role/your-sso-role"
```

### 2. Provision infrastructure

```bash
cd infra
terraform init
terraform apply
```

### 3. Connect kubectl

```bash
aws eks update-kubeconfig --name tptech-cluster --region us-east-1
kubectl get nodes
```

### 4. Deploy application

```bash
kubectl apply -f app/k8s/deployment.yaml
kubectl apply -f app/k8s/service.yaml
kubectl get svc tptech-app-service  # get LoadBalancer DNS
```

### 5. GitHub Actions secrets

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | ARN of `github-actions-eks-deploy` role |
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `SSO_ADMIN_ROLE_ARN` | ARN of your SSO administrator role |

## Destroy

Always delete Kubernetes resources before destroying infrastructure, otherwise the Load Balancer will block VPC deletion:

```bash
kubectl delete -f app/k8s/service.yaml
kubectl delete -f app/k8s/deployment.yaml
cd infra && terraform destroy
```

The S3 bucket must be deleted manually: empty it first (including all versions), then delete.

## Cost

| Resource | Cost |
|----------|------|
| EKS control plane | ~$0.10/hour |
| t3.medium x2 | ~$0.066/hour |
| **Total** | **~$3.98/day** |

Always run `terraform destroy` when not actively using the cluster.
