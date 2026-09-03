# locals {
#   ecr_repositories = [
#     "hotelservice",
#     "userservice",
#     "serviceregistry",
#     "ratingservice",
#     "apigatewayservice",
#     "frontendservice"
#   ]

#   common_tags = {
#     Environment = "production"
#     ManagedBy   = "terraform"
#   }
# }

# resource "aws_ecr_repository" "repos" {
#   for_each = toset(local.ecr_repositories)

#   name                 = each.value
#   image_tag_mutability = "MUTABLE"
#   force_delete         = true

#   image_scanning_configuration {
#     scan_on_push = true
#   }

#   encryption_configuration {
#     encryption_type = "AES256"
#   }

#   tags = merge(
#     local.common_tags,
#     {
#       Name = each.value
#     }
#   )
# }

# resource "aws_ecr_lifecycle_policy" "repos" {
#   for_each = aws_ecr_repository.repos

#   repository = each.value.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 10 images"

#         selection = {
#           tagStatus   = "any"
#           countType   = "imageCountMoreThan"
#           countNumber = 10
#         }

#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }


resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "my_key" {
  key_name   = "my-keypair"
  public_key = tls_private_key.my_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.my_key.private_key_pem
  filename = "my-keypair.pem"
}



data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}



# resource "aws_iam_role" "ec2_role" {
#   name = "devops-ec2-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecr_power_user" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
# }


# data "aws_iam_role" "node" {
#   name = "demoEKS"
# }

# resource "aws_iam_instance_profile" "ec2_profile" {
#   name = "devops-ec2-profile"
#   # role = aws_iam_role.ec2_role.name
#   role = data.aws_iam_role.node.name
# }


resource "aws_instance" "setup_ec2_backend" {
  ami                    = "ami-090d68841c2a28756"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [var.ec2_sg]
  # user_data              = file("${path.module}/user_data.sh")
  subnet_id = var.subnet_id

  # user_data = templatefile("${path.module}/userdata.sh.tpl", {
  #   ecr_repos = {
  #     for name, repo in aws_ecr_repository.repos :
  #     name => repo.repository_url
  #   }
  # })
  # user_data_replace_on_change = true

  # iam_instance_profile = "ECRFullAccess"
  # iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "SETUP-EC2-BACKEND"
  }
}

# resource "aws_instance" "setup_ec2_frontend" {
#   ami                    = data.aws_ami.amazon_linux_2023.id
#   instance_type          = "t3.micro"
#   # key_name               = aws_key_pair.my_key.key_name
#   vpc_security_group_ids = [var.ec2_sg]
#   # user_data              = file("${path.module}/user_data.sh")
#   subnet_id = var.subnet_id

#   user_data = templatefile("${path.module}/userdata1.sh.tpl", {
#     ecr_repos = {
#       for name, repo in aws_ecr_repository.repos :
#       name => repo.repository_url
#     }
#   })
#   user_data_replace_on_change = true

#   # iam_instance_profile = "ECRFullAccess"
#   iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
#   tags = {
#     Name = "SETUP-EC2-FRONTEND"
#   }

# }



# # output "ip" {
# #   value = aws_instance.example.public_ip
# #   # value = aws_ecr_repository.main
# # }


