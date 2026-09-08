# =====================================================================
# ROOT MODULE — wires network, security-group, iam and eks modules
# together into one deployable EKS cluster + node group(s).
# =====================================================================

# locals {
#   node_groups = {
#     for name, ng in var.node_groups : name => merge(
#       {
#         subnet_ids    = module.network.private_subnet_ids
#         node_role_arn = module.iam.node_role_arn
#       },
#       ng,
#     )
#   }
# }

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

# module "iam" {
#   source = "./modules/iam"

#   name = var.cluster_name
#   tags = var.tags
# }

# module "eks" {
#   source = "./modules/eks"

#   name               = var.cluster_name
#   kubernetes_version = var.kubernetes_version
#   cluster_role_arn   = module.iam.cluster_role_arn
#   node_role_arn      = module.iam.node_role_arn

#   subnet_ids                       = module.network.all_subnet_ids
#   control_plane_security_group_ids = [module.security_group.control_plane_additional_security_group_id]
#   shared_node_security_group_id    = module.security_group.shared_node_security_group_id
#   endpoint_public_access           = var.endpoint_public_access
#   endpoint_private_access          = var.endpoint_private_access
#   public_access_cidrs              = var.public_access_cidrs

#   node_groups = local.node_groups

#   cluster_addons       = var.cluster_addons
#   create_oidc_provider = var.create_oidc_provider
#   tags                 = var.tags
# }

# module "database" {
#   source = "./modules/database"

#   vpc_id                 = module.network.vpc_id
#   subnet_ids             = module.network.private_subnet_ids
#   allowed_cidr_blocks    = [var.vpc_cidr]
#   postgres_configuration = var.postgresql_database_config
#   mysql_configuration    = var.mysql_database_config
#   tags                   = var.tags
# }

module "setup_ec2" {
  source = "./modules/setup_ec2"

  key_name = var.key_name
  subnet_id = module.network.public_subnet_ids[0]
  ec2_sg    = module.security_group.setup_ec2_security_group_id
}
