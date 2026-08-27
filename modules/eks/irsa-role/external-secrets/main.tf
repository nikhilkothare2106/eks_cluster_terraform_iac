resource "aws_iam_policy" "external_secrets_myapp_dev" {
  name        = "external-secrets-myapp-dev-policy"
  description = "Allows reading the myapp dev secret from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadMyAppSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secret_arn
      }
    ]
  })
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  description        = "IAM role for serviceaccount \"${var.namespace}/${var.service_account_name}\" [managed by Terraform]"
  tags               = var.tags
}

# resource "aws_iam_role_policy_attachment" "this" {
#   for_each   = toset(var.policy_arns)
#   role       = aws_iam_role.this.name
#   policy_arn = each.value
# }


resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.external_secrets_myapp_dev.arn
}



resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service_account_v1" "external_secrets" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
  skip_crds  = false
  set = [
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.external_secrets.metadata[0].name
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.this,
    kubernetes_service_account_v1.external_secrets,
  ]
}


# resource "kubernetes_manifest" "cluster_secret_store" {
#   manifest = {
#     apiVersion = "external-secrets.io/v1"
#     kind       = "ClusterSecretStore"
#     metadata   = { name = "aws-secretsmanager-store" }
#     spec = {
#       provider = {
#         aws = {
#           service = "SecretsManager"
#           region  = var.aws_region
#           auth = {
#             jwt = {
#               serviceAccountRef = {
#                 name      = kubernetes_service_account_v1.external_secrets.metadata[0].name
#                 namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
#               }
#             }
#           }
#         }
#       }
#     }
#   }
#   depends_on = [helm_release.external_secrets]
# }