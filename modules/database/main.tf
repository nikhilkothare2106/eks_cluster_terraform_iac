module "postgres" {
  source = "./postgres"

  name                = var.postgres_configuration.name
  vpc_id              = var.vpc_id
  subnet_ids          = var.subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks
  availability_zone   = var.postgres_configuration.availability_zone
  configuration       = var.postgres_configuration
  tags                = var.tags
}

module "mysql" {
  source = "./mysql"

  name                = var.mysql_configuration.name
  vpc_id              = var.vpc_id
  subnet_ids          = var.subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks
  availability_zone   = var.mysql_configuration.availability_zone
  configuration       = var.mysql_configuration
  tags                = var.tags
}