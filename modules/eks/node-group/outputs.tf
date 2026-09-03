# output "node_group_arns" {
#   value = { for name, node_group in aws_eks_node_group.this : name => node_group.arn }
# }

# output "node_group_statuses" {
#   value = { for name, node_group in aws_eks_node_group.this : name => node_group.status }
# }
