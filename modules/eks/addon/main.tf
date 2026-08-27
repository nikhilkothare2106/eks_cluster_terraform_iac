resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name                = var.cluster_name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_update = each.value.resolve_conflicts
  service_account_role_arn    = each.value.service_account_role_arn

  tags = var.tags
}
