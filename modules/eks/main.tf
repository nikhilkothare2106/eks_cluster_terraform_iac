# =====================================================================
# EKS MODULE
# EKS cluster (control plane), the cross-referencing security group
# rules that depend on the cluster's own managed SG, managed node
# groups, and cluster addons.
# =====================================================================

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  bootstrap_self_managed_addons = true

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.control_plane_security_group_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(var.tags, {
    Name = "${var.name}/ControlPlane"
  })
}

# ---------------------------
# OIDC provider, required for IRSA (IAM Roles for Service Accounts) — lets
# pods (e.g. the vpc-cni or ebs-csi-driver addon, or your own workloads)
# assume IAM roles instead of using node instance profile permissions.
# ---------------------------
data "tls_certificate" "eks" {
  count = var.create_oidc_provider ? 1 : 0
  url   = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count = var.create_oidc_provider ? 1 : 0

  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name = "${var.name}/OIDCProvider"
  })
}

# # ---------------------------
# # Cross-referencing security group rules
# # (equivalent to IngressDefaultClusterToNodeSG / IngressInterNodeGroupSG /
# # IngressNodeToDefaultClusterSG in the reference CFN template)
# # ---------------------------

# Allow the cluster's own managed SG to reach nodes on all ports.
resource "aws_security_group_rule" "cluster_to_shared_node" {
  description              = "Allow managed and unmanaged nodes to communicate with each other (all ports)"
  type                     = "ingress"
  security_group_id        = var.shared_node_security_group_id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

# # # Allow nodes in the shared SG to talk to each other on all ports.
resource "aws_security_group_rule" "node_to_node" {
  description              = "Allow nodes to communicate with each other (all ports)"
  type                     = "ingress"
  security_group_id        = var.shared_node_security_group_id
  source_security_group_id = var.shared_node_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

# # Allow nodes to reach the control plane's managed SG on all ports
# # (needed for unmanaged/self-managed nodegroups; managed node groups get
# # this automatically, but it's harmless and matches the CFN template).
resource "aws_security_group_rule" "node_to_cluster" {
  description              = "Allow unmanaged nodes to communicate with control plane (all ports)"
  type                     = "ingress"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.shared_node_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

# # ---------------------------
# # Managed node groups
# # ---------------------------
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = coalesce(each.value.node_role_arn, var.default_node_role_arn)
  subnet_ids      = each.value.subnet_ids

  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  ami_type       = each.value.ami_type
  disk_size      = each.value.disk_size

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  #   # Node groups attach to the shared node SG automatically via the launch
  #   # template that EKS manages, plus we've already wired the shared SG's
  #   # ingress rules above. If you need a *custom* launch template (custom AMI,
  #   # extra volumes, extra SGs) add a `launch_template { }` block here and pass
  #   # var.shared_node_security_group_id into its vpc_security_group_ids.

  tags = merge(var.tags, {
    Name = "${var.name}/${each.key}"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size] # let cluster-autoscaler/karpenter own this after creation
  }

  depends_on = [
    aws_security_group_rule.cluster_to_shared_node,
    aws_security_group_rule.node_to_node,
    aws_security_group_rule.node_to_cluster,
  ]
}

# # ---------------------------
# # Cluster addons
# # ---------------------------
resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_update = each.value.resolve_conflicts
  service_account_role_arn    = each.value.service_account_role_arn

  tags = var.tags

  # depends_on = [aws_eks_node_group.this]
}
