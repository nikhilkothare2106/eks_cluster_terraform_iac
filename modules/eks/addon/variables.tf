variable "cluster_name" {
  type = string
}

variable "cluster_addons" {
  type = map(object({
    version                  = optional(string, null)
    resolve_conflicts        = optional(string, "OVERWRITE")
    service_account_role_arn = optional(string, null)
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
