# =====================================================================
# SECURITY GROUP MODULE
# Mirrors the two custom security groups from the reference CFN template:
#   - ControlPlaneSecurityGroup  -> "additional" SG attached to the cluster
#   - ClusterSharedNodeSecurityGroup -> shared SG attached to all node groups
#
# The three cross-referencing ingress rules that need the EKS cluster's own
# managed security group (created by AWS::EKS::Cluster / aws_eks_cluster)
# live in the eks module instead, since that ID only exists once the cluster
# itself has been created.
# =====================================================================
resource "aws_security_group" "control_plane_additional" {
  name        = "${var.name}-control-plane-additional"
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.additional_control_plane_ingress_rules

    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = length(ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : null
      security_groups = ingress.value.security_group_id != null ? [ingress.value.security_group_id] : null
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}/ControlPlaneSecurityGroup"
  })
}


resource "aws_security_group" "shared_node" {




  name        = "${var.name}-shared-node"
  description = "Communication between all nodes in the cluster"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.additional_node_ingress_rules

    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = length(ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : null
      security_groups = ingress.value.security_group_id != null ? [ingress.value.security_group_id] : null
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}/ClusterSharedNodeSecurityGroup"
  })
}