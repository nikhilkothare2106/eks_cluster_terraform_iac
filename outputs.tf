# output "vpc_id" {
#   value = module.network.vpc_id
# }

# output "public_subnet_ids" {
#   value = module.network.public_subnet_ids
# }

# output "private_subnet_ids" {
#   value = module.network.private_subnet_ids
# }

# output "private_azs" {
#   value = module.network.private_azs
# }

# output "cluster_name" {
#   value = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   value = module.eks.cluster_endpoint
# }

# output "cluster_certificate_authority_data" {
#   value     = module.eks.cluster_certificate_authority_data
#   sensitive = true
# }

# output "cluster_security_group_id" {
#   value = module.eks.cluster_security_group_id
# }

# output "oidc_provider_arn" {
#   value = module.eks.oidc_provider_arn
# }

# output "node_role_arn" {
#   value = module.iam.node_role_arn
# }

# output "configure_kubectl" {
#   description = "Run this to update your local kubeconfig."
#   value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
# }


#  output "node_groups" {
#   value = local.node_groups
# }
