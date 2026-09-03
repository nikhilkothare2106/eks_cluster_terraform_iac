variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_cidr_blocks" {
  type = list(string)
}

variable "availability_zone" {
  type = string
}

variable "configuration" {
  type = object({
    db_name                 = string
    username                = string
    password                = string
    port                    = number
    engine_version          = string
    instance_class          = string
    allocated_storage       = number
    storage_type            = string
    publicly_accessible     = bool
    skip_final_snapshot     = bool
    backup_retention_period = optional(number, 7)
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}