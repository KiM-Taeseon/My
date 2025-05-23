locals {
  vpc_name         = var.user_name
  cidr             = var.vpc_cidr
  az               = split(",", var.availability_zones[var.region])
  count            = length(local.az)
  public_subnets   = [for i in range(local.count) : cidrsubnet(local.cidr, 8, i)]
  private_subnets  = [for i in range(local.count) : cidrsubnet(local.cidr, 8, i + 100)]

  used_azs = distinct([
    for i in range(var.instance_count) :
    local.az[i % length(local.az)]
  ])

  used_public_subnet_map = {
    for idx, subnet in aws_subnet.public_subnets :
    local.az[idx] => subnet.id
    if contains(local.used_azs, local.az[idx])
  }

  az_to_private_subnet = {
    for idx, subnet in aws_subnet.private_subnets :
    local.az[idx] => subnet.id
  }
}

resource "aws_vpc" "test" {
  cidr_block = local.cidr
  tags       = { Name = local.vpc_name }
}

resource "aws_default_route_table" "test" {
  default_route_table_id = aws_vpc.test.default_route_table_id
  tags                   = { Name = "${local.vpc_name}-default-route" }
}

resource "aws_default_security_group" "test" {
  vpc_id = aws_vpc.test.id
  tags   = { Name = "${local.vpc_name}-default-sg" }
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id
  tags   = { Name = "${local.vpc_name}-igw" }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(local.public_subnets)
  vpc_id                  = aws_vpc.test.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.az[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.vpc_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count                   = length(local.private_subnets)
  vpc_id                  = aws_vpc.test.id
  cidr_block              = local.private_subnets[count.index]
  availability_zone       = local.az[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.vpc_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = {
    Name = "${local.vpc_name}-route-pub"
  }
}

resource "aws_route_table_association" "routing-asso-pub" {
  count          = length(local.az)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_eip" "nat_eips" {
  count  = length(local.used_azs)
  domain = "vpc"
}

resource "aws_nat_gateway" "multi_nat" {
  count         = length(local.used_azs)
  allocation_id = aws_eip.nat_eips[count.index].id
  subnet_id     = local.used_public_subnet_map[local.used_azs[count.index]]
  tags = {
    Name = "${local.vpc_name}-ngw-${local.used_azs[count.index]}"
  }
}

resource "aws_route_table" "private" {
  for_each = {
    for az in local.az :
    az => az
  }

  vpc_id = aws_vpc.test.id

  dynamic "route" {
    for_each = contains(local.used_azs, each.key) ? [1] : []

    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.multi_nat[
        index(local.used_azs, each.key)
      ].id
    }
  }

  tags = {
    Name = "${local.vpc_name}-pri-rt-${each.key}"
  }
}

resource "aws_route_table_association" "routing-asso-pri" {
  for_each = {
    for idx, subnet in aws_subnet.private_subnets :
    local.az[idx] => subnet.id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.private[each.key].id
}
