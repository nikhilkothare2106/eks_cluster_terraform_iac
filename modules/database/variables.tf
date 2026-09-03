variable "postgres_name" {
  description = "Logical name for the PostgreSQL RDS instance."
  type        = string
}

variable "mysql_name" {
  description = "Logical name for the MySQL RDS instance."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database security group will be created."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where the database subnet group will be created."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach PostgreSQL."
  type        = list(string)
}

variable "availability_zone" {
  description = "Single AZ to place this sandbox database instance in."
  type        = string
  default     = "ap-south-1a"
}

variable "postgres_configuration" {
  description = "PostgreSQL database instance settings."
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

variable "mysql_configuration" {
  description = "MySQL database instance settings."
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
  description = "Tags applied to the database resources."
  type        = map(string)
  default     = {}
}
