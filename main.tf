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


# module "external_secrets_irsa" {
#   source = "./modules/eks/irsa-role/external-secrets"

#   role_name            = var.external_secrets_irsa_role_name
#   oidc_provider_arn    = module.eks.oidc_provider_arn
#   oidc_provider_url    = trimprefix(module.eks.oidc_issuer_url, "https://")
#   namespace            = var.external_secrets_namespace
#   service_account_name = var.external_secrets_service_account_name
#   aws_region           = var.aws_region
#   secret_arn           = var.external_store_secret_arn
#   tags = {
#     ManagedBy = "terraform"
#   }
#   depends_on = [module.eks, module.alb_irsa]
# }

# module "alb_irsa" {
#   source = "./modules/eks/irsa-role/alb"

#   cluster_name      = module.eks.cluster_name
#   oidc_provider_arn = module.eks.oidc_provider_arn
#   oidc_provider_url = trimprefix(module.eks.oidc_issuer_url, "https://")
#   policy_arn        = var.alb_irsa_policy_arn
#   namespace         = var.alb_irsa_namespace
#   role_name         = var.alb_irsa_role_name
#   aws_region        = var.aws_region
#   vpc_id            = module.network.vpc_id
#   tags = {
#     ManagedBy = "terraform"
#   }
#   depends_on = [module.eks]
# }

# module "argocd" {
#   source = "./modules/eks/argocd"

#   chart_version    = var.argocd_chart_version
#   values           = var.argocd_values
#   create_namespace = var.argocd_create_namespace
#   wait             = var.argocd_wait
#   atomic           = var.argocd_atomic
#   cleanup_on_fail  = var.argocd_cleanup_on_fail
#   timeout          = var.argocd_timeout

#   depends_on = [module.eks]
# }