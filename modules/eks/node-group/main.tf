resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix            = "${var.name}-${each.key}-"
  update_default_version = true
  vpc_security_group_ids = [
    var.shared_node_security_group_id,
    var.cluster_security_group_id,
  ]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name}/${each.key}"
    })
  }
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = var.cluster_name
  node_group_name = each.key
  node_role_arn   = coalesce(each.value.node_role_arn, var.default_node_role_arn)
  subnet_ids      = each.value.subnet_ids

  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  ami_type       = each.value.ami_type

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}/${each.key}"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

}
