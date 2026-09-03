output "db_instance_id" {
  description = "RDS PostgreSQL identifier."
  value       = module.postgres.db_instance_id
}

output "db_instance_endpoint" {
  description = "RDS PostgreSQL hostname."
  value       = module.postgres.db_instance_endpoint
}

output "db_instance_port" {
  description = "Port used by PostgreSQL."
  value       = module.postgres.db_instance_port
}

output "db_security_group_id" {
  description = "Security group ID attached to the database."
  value       = module.postgres.db_security_group_id
}

output "mysql_db_instance_id" {
  description = "RDS MySQL identifier."
  value       = module.mysql.db_instance_id
}

output "mysql_db_instance_endpoint" {
  description = "RDS MySQL hostname."
  value       = module.mysql.db_instance_endpoint
}

output "mysql_db_instance_port" {
  description = "Port used by MySQL."
  value       = module.mysql.db_instance_port
}

output "mysql_db_security_group_id" {
  description = "MySQL security group ID attached to the database."
  value       = module.mysql.db_security_group_id
}
