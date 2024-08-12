terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPCs
resource "aws_vpc" "vpcs" {
  for_each = var.vpcs
  cidr_block           = each.value.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "VPC-${upper(each.key)}" }
}

# IGW for VPC-A
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpcs["a"].id
  tags = {
    Name = "Main IGW"
  }
}

# Subnets
resource "aws_subnet" "subnets" {
  for_each = merge([
    for vpc_key, vpc in var.vpcs : {
      for subnet_key, cidr in vpc.subnets :
      "${vpc_key}_${subnet_key}" => {
        vpc_id     = aws_vpc.vpcs[vpc_key].id
        cidr_block = cidr
        vpc_key    = vpc_key
        subnet_key = subnet_key
      }
    }
  ]...)
  vpc_id     = each.value.vpc_id
  cidr_block = each.value.cidr_block
  tags       = { Name = "Subnet-${upper(each.value.vpc_key)}-${each.value.subnet_key}" }
}

# VPC Peering
resource "aws_vpc_peering_connection" "peering" {
  count       = 2
  vpc_id      = aws_vpc.vpcs["a"].id
  peer_vpc_id = aws_vpc.vpcs[local.vpc_names[count.index + 1]].id
  auto_accept = true
  tags        = { Name = "VPC-A to VPC-${upper(local.vpc_names[count.index + 1])} Peering" }
}

# Route Table for VPC-A
resource "aws_route_table" "rt_a" {
  vpc_id = aws_vpc.vpcs["a"].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    cidr_block                = "192.168.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peering[0].id
  }

  tags = { Name = "Route Table VPC-A" }
}

# Route Tables for VPC-B and VPC-C
resource "aws_route_table" "rt_bc" {
  count  = 2
  vpc_id = aws_vpc.vpcs[local.vpc_names[count.index + 1]].id

  route {
    cidr_block                = var.vpcs["a"].cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering[count.index].id
  }

  tags = { Name = "Route Table VPC-${upper(local.vpc_names[count.index + 1])}" }
}

# Route Table Associations
resource "aws_route_table_association" "rta_a" {
  for_each       = { for k, v in aws_subnet.subnets : k => v if split("_", k)[0] == "a" }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt_a.id
}

resource "aws_route_table_association" "rta_bc" {
  for_each       = { for k, v in aws_subnet.subnets : k => v if split("_", k)[0] != "a" }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt_bc[split("_", each.key)[0] == "b" ? 0 : 1].id
}

# Security Groups
resource "aws_security_group" "security_groups" {
  for_each    = aws_vpc.vpcs
  name        = "Allow ICMP and SSH VPC-${upper(each.key)}"
  description = "Allow ICMP and SSH traffic"
  vpc_id      = each.value.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Allow ICMP and SSH traffic VPC-${upper(each.key)}" }
}

# IAM Role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "SSM-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm_role.name
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSM-Instance-Profile"
  role = aws_iam_role.ssm_role.name
}

# EC2 Instances
resource "aws_instance" "servers" {
  for_each = {
    ab = { vpc = "a", subnet = "subnet1", name = "AB", public_ip = true }
    ac = { vpc = "a", subnet = "subnet2", name = "AC", public_ip = true }
    b  = { vpc = "b", subnet = "subnet1", name = "B",  public_ip = false }
    c  = { vpc = "c", subnet = "subnet1", name = "C",  public_ip = false }
  }

  ami           = "ami-009c9406091cbd65a"
  instance_type = "t2.micro"
  associate_public_ip_address = each.value.public_ip
  subnet_id     = aws_subnet.subnets["${each.value.vpc}_${each.value.subnet}"].id
  vpc_security_group_ids = [aws_security_group.security_groups[each.value.vpc].id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "Server-${each.value.name}"
  }
}