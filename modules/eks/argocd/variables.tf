variable "chart_version" {
  description = "Optional pinned Argo CD chart version. Null uses the repository default."
  type        = string
  default     = null
}

variable "create_namespace" {
  description = "Create the Argo CD namespace when it does not exist."
  type        = bool
  default     = true
}

variable "values" {
  description = "YAML documents passed to the Argo CD Helm chart."
  type        = list(string)
  default     = []
}

variable "wait" {
  description = "Wait for Argo CD resources to become ready."
  type        = bool
  default     = true
}

variable "atomic" {
  description = "Roll back the release if installation fails."
  type        = bool
  default     = true
}

variable "cleanup_on_fail" {
  description = "Delete newly created resources if the release fails."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Maximum time in seconds to wait for the Helm release."
  type        = number
  default     = 900
}
