output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_arn" {
  value = module.cluster.cluster_arn
}

output "cluster_endpoint" {
  value = module.cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.cluster.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "The EKS-managed primary security group (equivalent to ClusterSecurityGroupId in the CFN template)."
  value       = module.cluster.cluster_security_group_id
}

output "oidc_issuer_url" {
  value = module.cluster.oidc_issuer_url
}

output "oidc_provider_arn" {
  value = module.cluster.oidc_provider_arn
}

output "node_group_arns" {
  value = module.node_group.node_group_arns
}

output "node_group_statuses" {
  value = module.node_group.node_group_statuses
}
