resource "aws_db_subnet_group" "database" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}/DatabaseSubnetGroup"
  })
}

resource "aws_security_group" "database" {
  name        = "${var.name}-postgres"
  description = "Allow PostgreSQL access from the VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = var.configuration.port
    to_port     = var.configuration.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}/DatabaseSecurityGroup"
  })
}

resource "aws_db_instance" "database" {
  identifier             = var.name
  db_name                = var.configuration.db_name
  username               = var.configuration.username
  password               = var.configuration.password
  port                   = var.configuration.port
  engine                 = "postgres"
  engine_version         = var.configuration.engine_version
  instance_class         = var.configuration.instance_class
  allocated_storage      = var.configuration.allocated_storage
  storage_type           = var.configuration.storage_type
  availability_zone      = var.availability_zone
  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible        = var.configuration.publicly_accessible
  skip_final_snapshot        = var.configuration.skip_final_snapshot
  backup_retention_period    = var.configuration.backup_retention_period
  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.name}/PostgreSQL"
  })
}