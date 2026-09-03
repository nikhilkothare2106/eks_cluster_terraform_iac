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
  node_groups                   = var.node_groups
  tags                          = var.tags

  depends_on = [module.addon_before_nodes]
}

module "addon_before_nodes" {
  source = "./addon"

  cluster_name = module.cluster.cluster_name
  cluster_addons = {
    for name, addon in var.cluster_addons : name => addon
    if addon.before_compute
  }
  tags = var.tags
}

module "addon_after_nodes" {
  source = "./addon"

  cluster_name = module.cluster.cluster_name
  cluster_addons = {
    for name, addon in var.cluster_addons : name => addon
    if !addon.before_compute
  }
  tags = var.tags

  depends_on = [module.node_group]
}