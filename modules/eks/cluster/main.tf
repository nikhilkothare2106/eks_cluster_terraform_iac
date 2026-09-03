resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  bootstrap_self_managed_addons = false

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

  
  # # EKS Auto Mode compute
  # compute_config {
  #   enabled       = true
  #   node_pools    = ["general-purpose", "system"]
  #   node_role_arn = var.default_node_role_arn
  # }

  # # EKS Auto Mode load balancing/networking capability
  # kubernetes_network_config {
  #   elastic_load_balancing {
  #     enabled = true
  #   }
  # }

  # # EKS Auto Mode block storage
  # storage_config {
  #   block_storage {
  #     enabled = true
  #   }
  # }
}

# data "tls_certificate" "eks" {
#   count = var.create_oidc_provider ? 1 : 0
#   url   = aws_eks_cluster.this.identity[0].oidc[0].issuer
# }

# resource "aws_iam_openid_connect_provider" "eks" {
#   count = var.create_oidc_provider ? 1 : 0

#   url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]

#   tags = merge(var.tags, {
#     Name = "${var.name}/OIDCProvider"
#   })
# }

resource "aws_security_group_rule" "cluster_to_shared_node" {
  description              = "Allow managed and unmanaged nodes to communicate with each other (all ports)"
  type                     = "ingress"
  security_group_id        = var.shared_node_security_group_id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

resource "aws_security_group_rule" "node_to_node" {
  description              = "Allow nodes to communicate with each other (all ports)"
  type                     = "ingress"
  security_group_id        = var.shared_node_security_group_id
  source_security_group_id = var.shared_node_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

resource "aws_security_group_rule" "node_to_cluster" {
  description              = "Allow unmanaged nodes to communicate with control plane (all ports)"
  type                     = "ingress"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.shared_node_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}
