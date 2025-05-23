locals {
  instance_type   = var.instance_type
  instance_count  = var.instance_count
  subnet_ids      = [for subnet in aws_subnet.private_subnets : subnet.id]
}

resource "aws_key_pair" "aws-public-key" {
  key_name   = "${var.user_name}-key"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "aws_instance" "web2" {
  count = local.instance_count

  ami                    = aws_ami_from_instance.ami.id
  instance_type          = local.instance_type
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  subnet_id              = local.subnet_ids[count.index % length(local.subnet_ids)]
  associate_public_ip_address = false
  key_name               = aws_key_pair.aws-public-key.key_name

  tags = {
    Name = "${var.user_name}-${count.index}"
  }

  depends_on = [aws_ami_from_instance.ami]
}

resource "aws_instance" "bastion-host" {
  ami                    = aws_ami_from_instance.ami.id
  instance_type          = "t2.small"
  vpc_security_group_ids = [aws_security_group.bastion-sg.id]
  subnet_id              = aws_subnet.public_subnets[0].id
  associate_public_ip_address = true
  key_name               = aws_key_pair.aws-public-key.key_name

  tags = {
    Name = "bastion-host"
  }

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /home/ec2-user/.ssh
              cat <<EOKEY > /home/ec2-user/.ssh/private_key.pem
              ${tls_private_key.private_key.private_key_pem}
              EOKEY
              chmod 600 /home/ec2-user/.ssh/private_key.pem
              chown ec2-user:ec2-user /home/ec2-user/.ssh/private_key.pem
              EOF

  depends_on = [aws_instance.web2]
}

resource "aws_security_group" "instance-sg" {
  name        = "${var.user_name}-web-sg"
  description = "security group for instance"
  vpc_id      = aws_vpc.test.id

  ingress {
    description = "Allow TLS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTP"
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow ICMP"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    security_groups = [ aws_security_group.bastion-sg.id ]
  }
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ aws_security_group.bastion-sg.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.user_name}-web-sg"
  }
}

resource "aws_security_group" "bastion-sg" {
  name        = "bastion-sg"
  description = "security group for bastion host"
  vpc_id      = aws_vpc.test.id

  ingress {
    description = "Allow ICMP"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH"
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

  tags = {
    Name = "bastion-sg"
  }
}