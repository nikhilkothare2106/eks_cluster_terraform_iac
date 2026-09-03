output "db_instance_id" {
  value = aws_db_instance.database.id
}

output "db_instance_endpoint" {
  value = aws_db_instance.database.address
}

output "db_instance_port" {
  value = aws_db_instance.database.port
}

output "db_security_group_id" {
  value = aws_security_group.database.id
}