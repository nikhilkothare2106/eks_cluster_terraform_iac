# =====================================================================
# ROOT MODULE — wires network, security-group, iam and eks modules
# together into one deployable EKS cluster + node group(s).
# =====================================================================

locals {
  # Inject sensible defaults (private subnets, the IAM module's node role)
  # into every node group entry the caller didn't fully specify.
  node_groups = {
    for name, ng in var.node_groups : name => merge(
      {
        subnet_ids    = module.network.private_subnet_ids
        node_role_arn = module.iam.node_role_arn
      },
      ng,
    )
  }
}

module "network" {
  source = "./modules/network"

  name               = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway
  tags               = var.tags
  subnet_config      = var.subnet_config
}

module "security_group" {
  source = "./modules/security-group"

  name   = var.cluster_name
  vpc_id = module.network.vpc_id
  tags   = var.tags
}

module "iam" {
  source = "./modules/iam"

  name = var.cluster_name
  tags = var.tags
}

module "eks" {
  source = "./modules/eks"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  cluster_role_arn   = module.iam.cluster_role_arn

  # Matches the reference CFN template: both public and private subnets are
  # handed to the cluster's ResourcesVpcConfig.
  subnet_ids                       = module.network.all_subnet_ids
  control_plane_security_group_ids = [module.security_group.control_plane_additional_security_group_id]
  shared_node_security_group_id    = module.security_group.shared_node_security_group_id
  endpoint_public_access           = var.endpoint_public_access
  endpoint_private_access          = var.endpoint_private_access
  public_access_cidrs              = var.public_access_cidrs

  default_node_role_arn = module.iam.node_role_arn
  node_groups           = local.node_groups

  cluster_addons       = var.cluster_addons
  create_oidc_provider = var.create_oidc_provider
  tags                 = var.tags
}