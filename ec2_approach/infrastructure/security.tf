### infrastructure/security.tf
# Security Group
resource "aws_security_group" "terraform_sg" {
  name        = "terraform-runner-sg"
  description = "Security group for Terraform runner EC2 instance"
  vpc_id      = aws_vpc.terraform_vpc.id
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr
  }
  
  # HTTP for webhook
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.webhook_allowed_cidr
  }
  
  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "terraform-runner-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "terraform_role" {
  name = "terraform-runner-role"
  
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

# IAM Policy for Terraform operations
resource "aws_iam_policy" "terraform_policy" {
  name        = "terraform-runner-policy"
  description = "Policy for EC2 instance to provision resources using Terraform"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}",
          "${aws_s3_bucket.terraform_state.arn}/*",
          "${aws_s3_bucket.terraform_configs.arn}",
          "${aws_s3_bucket.terraform_configs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "${aws_dynamodb_table.terraform_locks.arn}"
      },
      # Resources that the Terraform can provision
      # In production, limit these to specifically required services
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "rds:*",
          "dynamodb:*",
          "iam:*",
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "terraform_attachment" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = aws_iam_policy.terraform_policy.arn
}

# IAM instance profile
resource "aws_iam_instance_profile" "terraform_profile" {
  name = "terraform-runner-profile"
  role = aws_iam_role.terraform_role.name
}

# Security Group for Project Builder
resource "aws_security_group" "project_builder_sg" {
  name        = "project-builder-sg"
  description = "Security group for Project Builder EC2 instance"
  vpc_id      = aws_vpc.terraform_vpc.id
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr
  }
  
  # HTTP for project builder webhook
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = var.webhook_allowed_cidr
  }
  
  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "project-builder-sg"
  }
}

# IAM Role for Project Builder EC2
resource "aws_iam_role" "project_builder_role" {
  name = "project-builder-role"
  
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

# IAM Policy for Project Builder operations
resource "aws_iam_policy" "project_builder_policy" {
  name        = "project-builder-policy"
  description = "Policy for Project Builder EC2 instance"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.terraform_configs.arn}",
          "${aws_s3_bucket.terraform_configs.arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "project_builder_attachment" {
  role       = aws_iam_role.project_builder_role.name
  policy_arn = aws_iam_policy.project_builder_policy.arn
}

# IAM instance profile for Project Builder
resource "aws_iam_instance_profile" "project_builder_profile" {
  name = "project-builder-profile"
  role = aws_iam_role.project_builder_role.name
}