output "release_name" {
  description = "Argo CD Helm release name."
  value       = helm_release.this.name
}

output "namespace" {
  description = "Namespace containing Argo CD."
  value       = helm_release.this.namespace
}

output "status" {
  description = "Current Helm release status."
  value       = helm_release.this.status
}
