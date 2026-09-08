output "cluster_role_arn" {
  # value = data.aws_iam_role.cluster.arn
  value = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  # value = data.aws_iam_role.cluster.name
  value = aws_iam_role.cluster.name
}


output "node_role_arn" {
  # value = data.aws_iam_role.node.arn
  value = aws_iam_role.node.arn
}

output "node_role_name" {
  # value = data.aws_iam_role.node.name
  value = aws_iam_role.node.name
}

# # output "node_instance_profile_name" {
# #   value = aws_iam_instance_profile.node.name
# # }

# # output "fargate_role_arn" {
# #   value = var.create_fargate_role ? aws_iam_role.fargate[0].arn : null
# # }
