module "cluster" {
  source = "./cluster"

  name                                        = var.name
  kubernetes_version                          = var.kubernetes_version
  cluster_role_arn                            = var.cluster_role_arn
  subnet_ids                                  = var.subnet_ids
  control_plane_security_group_ids            = var.control_plane_security_group_ids
  shared_node_security_group_id               = var.shared_node_security_group_id
  endpoint_private_access                     = var.endpoint_private_access
  endpoint_public_access                      = var.endpoint_public_access
  public_access_cidrs                         = var.public_access_cidrs
  authentication_mode                         = var.authentication_mode
  bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  enabled_cluster_log_types                   = var.enabled_cluster_log_types
  create_oidc_provider                        = var.create_oidc_provider
  tags                                        = var.tags
}

module "node_group" {
  source = "./node-group"

  name                          = var.name
  cluster_name                  = module.cluster.cluster_name
  cluster_security_group_id     = module.cluster.cluster_security_group_id
  shared_node_security_group_id = var.shared_node_security_group_id
  default_node_role_arn         = var.default_node_role_arn
  node_groups                   = var.node_groups
  tags                          = var.tags
}

module "addon" {
  source = "./addon"

  cluster_name   = module.cluster.cluster_name
  cluster_addons = var.cluster_addons
  tags           = var.tags

  depends_on = [module.node_group]
}

moved {
  from = aws_eks_cluster.this
  to   = module.cluster.aws_eks_cluster.this
}

moved {
  from = aws_iam_openid_connect_provider.eks[0]
  to   = module.cluster.aws_iam_openid_connect_provider.eks[0]
}

moved {
  from = aws_security_group_rule.cluster_to_shared_node
  to   = module.cluster.aws_security_group_rule.cluster_to_shared_node
}

moved {
  from = aws_security_group_rule.node_to_node
  to   = module.cluster.aws_security_group_rule.node_to_node
}

moved {
  from = aws_security_group_rule.node_to_cluster
  to   = module.cluster.aws_security_group_rule.node_to_cluster
}

moved {
  from = aws_launch_template.node
  to   = module.node_group.aws_launch_template.node
}

moved {
  from = aws_eks_node_group.this
  to   = module.node_group.aws_eks_node_group.this
}

moved {
  from = aws_eks_addon.this
  to   = module.addon.aws_eks_addon.this
}
