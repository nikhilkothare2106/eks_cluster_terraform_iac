resource "helm_release" "this" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = var.create_namespace
  version          = var.chart_version

  values = var.values

  wait            = var.wait
  atomic          = var.atomic
  cleanup_on_fail = var.cleanup_on_fail
  timeout         = var.timeout
}
