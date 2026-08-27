# EKS Terraform Modules

A modular Terraform layout for an EKS cluster, translated from an
eksctl-generated CloudFormation template into reusable modules.

## Layout

```
.
├── main.tf                    # root module: wires everything together
├── variables.tf
├── outputs.tf
├── versions.tf                 # provider requirements
├── terraform.tfvars.example
└── modules/
    ├── network/                # VPC, public/private subnets, IGW, NAT GW(s), route tables
    ├── security-group/         # control-plane-additional SG + shared-node SG
    ├── iam/                    # cluster service role, node role, optional fargate role
    ├── eks/                    # EKS cluster, SG cross-rules, node groups, addons, OIDC provider
    └── argocd/                 # Argo CD Helm release
```

## What each module does

- **network** — VPC + 3 public / 3 private subnets across AZs (configurable via
  `subnet_config`), one Internet Gateway, one shared NAT Gateway by default
  (`single_nat_gateway = true`, matching the reference CFN template's
  `FeatureNATMode: Single`) or one NAT Gateway per AZ if you set it to `false`,
  and per-AZ private route tables.
- **security-group** — the two "custom" security groups from the CFN template
  (`ControlPlaneSecurityGroup` and `ClusterSharedNodeSecurityGroup`), plus
  optional extra ingress rules you can pass in (bastion access, VPN CIDR, etc).
- **iam** — the cluster service role (`AmazonEKSClusterPolicy` +
  `AmazonEKSVPCResourceController`), the managed node group role
  (`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`,
  `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore`), and
  an optional Fargate pod execution role.
- **eks** — the `aws_eks_cluster` itself (API_AND_CONFIG_MAP auth mode +
  `bootstrapClusterCreatorAdminPermissions`, matching the CFN
  `AccessConfig`), the three cross-referencing security group rules that
  can only be created once the cluster's own managed SG exists, one or more
  `aws_eks_node_group`s, cluster addons (vpc-cni / coredns / kube-proxy /
  etc.), and the IAM OIDC provider needed for IRSA.
- **argocd** — installs Argo CD from the official Argo Helm repository after
  the EKS cluster is available. Set `argocd_chart_version` to pin a chart
  release and use `argocd_values` for chart settings.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: cluster_name, region, node group sizing, CIDR allow-list...

terraform init
terraform plan
terraform apply
```

After apply:

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name>
kubectl get nodes
```

## Notes / things to review before production use

- `endpoint_public_access` is `true` with `public_access_cidrs = ["0.0.0.0/0"]`
  by default (same as the reference CFN template) — restrict this to a known
  CIDR (office/VPN) or set `endpoint_private_access = true` and access via a
  bastion / VPN for production.
- `kubernetes_version` defaults to `1.31` — check
  https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  for what's currently supported and pick accordingly (the source CFN
  template referenced `1.36`, which may not exist yet depending on when
  you're reading this).
- Node groups' `desired_size` is set to `ignore_changes` in the eks module so
  that cluster-autoscaler / Karpenter can manage it after creation without
  Terraform fighting it on every plan — remove that `lifecycle` block if you
  want Terraform to be the sole source of truth for node count.
- `single_nat_gateway = true` is cheaper but means all AZs lose internet
  egress if that one NAT Gateway's AZ has an outage. Set it to `false` for a
  highly-available (and more expensive) NAT setup.
- Add a `launch_template` block inside `aws_eks_node_group` in
  `modules/eks/main.tf` if you need custom AMIs, extra EBS volumes, or extra
  security groups on nodes.
