# EC2 Terraform Provisioner - Organized by Files

## Infrastructure Setup Files

### infrastructure/main.tf
provider "aws" {
  region = var.aws_region
}

# VPC for security
resource "aws_vpc" "terraform_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "terraform-runner-vpc"
  }
}

# Subnet
resource "aws_subnet" "terraform_subnet" {
  vpc_id                  = aws_vpc.terraform_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  
  tags = {
    Name = "terraform-runner-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "terraform_igw" {
  vpc_id = aws_vpc.terraform_vpc.id
  
  tags = {
    Name = "terraform-runner-igw"
  }
}

# Route Table
resource "aws_route_table" "terraform_route_table" {
  vpc_id = aws_vpc.terraform_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_igw.id
  }
  
  tags = {
    Name = "terraform-runner-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "terraform_rta" {
  subnet_id      = aws_subnet.terraform_subnet.id
  route_table_id = aws_route_table.terraform_route_table.id
}

# EC2 instance
resource "aws_instance" "terraform_runner" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.terraform_subnet.id
  vpc_security_group_ids = [aws_security_group.terraform_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.terraform_profile.name
  
  user_data = templatefile("${path.module}/user_data.sh", {
    state_bucket = aws_s3_bucket.terraform_state.bucket
    config_bucket = aws_s3_bucket.terraform_configs.bucket
    lock_table = aws_dynamodb_table.terraform_locks.name
    aws_region = var.aws_region
  })
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
  tags = {
    Name = "terraform-runner"
  }
}

# Elastic IP for the instance
resource "aws_eip" "terraform_eip" {
  instance = aws_instance.terraform_runner.id
  domain   = "vpc"
  
  tags = {
    Name = "terraform-runner-eip"
  }
}

# Project Builder EC2 instance
resource "aws_instance" "project_builder" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  key_name               = var.key_name
  subnet_id              = aws_subnet.terraform_subnet.id
  vpc_security_group_ids = [aws_security_group.project_builder_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.project_builder_profile.name
  
  user_data = templatefile("${path.module}/project_builder_user_data.sh", {
    config_bucket = aws_s3_bucket.terraform_configs.bucket
    aws_region = var.aws_region
  })
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
  tags = {
    Name = "project-builder"
    Role = "terraform-project-generator"
  }
}

# Elastic IP for the project builder instance
resource "aws_eip" "project_builder_eip" {
  instance = aws_instance.project_builder.id
  domain   = "vpc"
  
  tags = {
    Name = "project-builder-eip"
  }
}