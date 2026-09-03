output "private_key_pem" {
  description = "Private SSH key generated for the setup EC2 instance."
  value       = tls_private_key.my_key.private_key_pem
  sensitive   = true
}

output "key_name" {
  description = "Name of the EC2 key pair."
  value       = aws_key_pair.my_key.key_name
}

# output "private_key_path" {
#   value = "${path.module}/my-keypair.pem"
# }

output "ssh_command" {
  value = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.setup_ec2_backend.public_ip}"
}