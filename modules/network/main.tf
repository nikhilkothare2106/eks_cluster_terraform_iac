# =====================================================================
# NETWORK MODULE
# VPC, public/private subnets across multiple AZs, IGW, NAT Gateway(s),
# and route tables. Modeled after the eksctl-generated CloudFormation
# template (single NAT by default) but written as reusable Terraform.
# =====================================================================

# ---------------------------
# VPC
# ---------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, {
    Name = "${var.name}/VPC"
  })
}

# ---------------------------
# Internet Gateway
# ---------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}/InternetGateway"
  })
}

# resource "aws_vpc_dhcp_options" "this" {
#   count               = 0 # placeholder for future custom DHCP options, not used today
#   domain_name_servers = ["AmazonProvidedDNS"]
# }

# # ---------------------------
# # Subnets (public + private, driven entirely by var.subnet_config)
# # ---------------------------
resource "aws_subnet" "subnets" {
  for_each = var.subnet_config

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public ? var.map_public_ip_on_launch : false

  tags = merge(var.tags, {
    Name = "${var.name}/${each.key}"
    # Required by the AWS Load Balancer Controller / in-tree ELB provisioner
    # to auto-discover subnets for internet-facing vs internal load balancers.
    "kubernetes.io/role/elb"            = each.value.public ? "1" : null
    "kubernetes.io/role/internal-elb"   = each.value.public ? null : "1"
    "kubernetes.io/cluster/${var.name}" = "shared"
  })
}

locals {
  public_subnets = {
    for key, subnet in aws_subnet.subnets :
    key => subnet if var.subnet_config[key].public
  }

  private_subnets = {
    for key, subnet in aws_subnet.subnets :
    key => subnet if !var.subnet_config[key].public
  }

  # First public subnet per AZ, used to place the (or a) NAT Gateway.
  public_subnet_by_az = {
    for key, subnet in local.public_subnets :
    subnet.availability_zone => subnet...
  }

  private_azs = toset([for s in local.private_subnets : s.availability_zone])

  # Place a shared NAT in the first public AZ, keeping the choice stable.
  nat_azs = var.single_nat_gateway ? toset([sort(keys(local.public_subnet_by_az))[0]]) : local.private_azs
}

# # ---------------------------
# # Elastic IPs for NAT Gateway(s)
# # ---------------------------
resource "aws_eip" "nat" {
  for_each = local.nat_azs

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}/NATIP-${each.key}"
  })

  depends_on = [aws_internet_gateway.igw]
}

# # ---------------------------
# # NAT Gateway(s)
# # ---------------------------
resource "aws_nat_gateway" "this" {
  for_each = local.nat_azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = local.public_subnet_by_az[each.key][0].id

  tags = merge(var.tags, {
    Name = "${var.name}/NATGateway-${each.key}"
  })

  depends_on = [aws_internet_gateway.igw]
}

# # ---------------------------
# # Public route table (single, shared by all public subnets)
# # ---------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}/PublicRouteTable"
  })
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# # ---------------------------
# # Private route tables (one per AZ that has a private subnet)
# # ---------------------------
resource "aws_route_table" "private" {
  for_each = local.private_azs

  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}/PrivateRouteTable-${each.key}"
  })
}

resource "aws_route" "private_nat_access" {
  for_each = local.private_azs

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  # When single_nat_gateway = true every AZ routes through the one NAT Gateway
  # that exists; otherwise each AZ routes through its own.
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[tolist(local.nat_azs)[0]].id : aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.value.availability_zone].id
}
