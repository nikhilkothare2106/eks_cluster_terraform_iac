output "cluster_role_arn" {
  value = aws_iam_role.cluster.arn
}

# output "cluster_role_name" {
#   value = aws_iam_role.cluster.name
# }

output "node_role_arn" {
  value = var.create_node_role ? aws_iam_role.node[0].arn : null
}

# output "node_role_name" {
#   value = var.create_node_role ? aws_iam_role.node[0].name : null
# }

# output "node_instance_profile_name" {
#   value = var.create_node_role ? aws_iam_instance_profile.node[0].name : null
# }

# output "fargate_role_arn" {
#   value = var.create_fargate_role ? aws_iam_role.fargate[0].arn : null
# }
