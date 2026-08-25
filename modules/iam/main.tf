# =====================================================================
# IAM MODULE
# EKS cluster service role, managed node group role, and (optionally) a
# Fargate profile pod execution role.
# =====================================================================

data "aws_partition" "current" {}

# ---------------------------
# Cluster (control plane) service role
# Equivalent to "ServiceRole" in the reference CFN template.
# ---------------------------
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json

  tags = merge(var.tags, {
    Name = "${var.name}/ServiceRole"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role_policy_attachment" "cluster_additional" {
  for_each = toset(var.cluster_service_role_additional_policy_arns)

  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

# # ---------------------------
# # Managed node group role
# # ---------------------------
data "aws_iam_policy_document" "node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  count = var.create_node_role ? 1 : 0

  name               = "${var.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json

  tags = merge(var.tags, {
    Name = "${var.name}/NodeInstanceRole"
  })
}

locals {
  node_base_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
  node_ssm_policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"

  node_policy_arns = concat(
    local.node_base_policy_arns,
    var.enable_ssm_on_nodes ? [local.node_ssm_policy_arn] : [],
    var.node_role_additional_policy_arns,
  )
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = var.create_node_role ? toset(local.node_policy_arns) : toset([])

  role       = aws_iam_role.node[0].name
  policy_arn = each.value
}

# resource "aws_iam_instance_profile" "node" {
#   count = var.create_node_role ? 1 : 0

#   name = "${var.name}-node-profile"
#   role = aws_iam_role.node[0].name

#   tags = var.tags
# }

# # ---------------------------
# # Fargate profile pod execution role (optional)
# # ---------------------------
# data "aws_iam_policy_document" "fargate_assume" {
#   count = var.create_fargate_role ? 1 : 0

#   statement {
#     effect  = "Allow"
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["eks-fargate-pods.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "fargate" {
#   count = var.create_fargate_role ? 1 : 0

#   name               = "${var.name}-fargate-role"
#   assume_role_policy = data.aws_iam_policy_document.fargate_assume[0].json

#   tags = merge(var.tags, {
#     Name = "${var.name}/FargatePodExecutionRole"
#   })
# }

# resource "aws_iam_role_policy_attachment" "fargate" {
#   count = var.create_fargate_role ? 1 : 0

#   role       = aws_iam_role.fargate[0].name
#   policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
# }
