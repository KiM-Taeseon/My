resource "aws_db_subnet_group" "db-subnet-group" {
  name = "db subnet group"
  subnet_ids = [for subnet in aws_subnet.private_subnets : subnet.id]
}

resource "aws_db_instance" "db-instance" {
  count = var.db_count
  db_name = "defaultdb${count.index}"
  identifier = "${var.db_identifier}${count.index}"
  allocated_storage = var.rds-allocated_storage
  instance_class = var.rds["instnace_class"]
  port = var.rds-ports["${var.rds["engine_name"]}"]
  engine = var.rds["engine_name"]
  engine_version = var.rds["engine_version"]

  username = var.db_username
  password = var.db_password
  skip_final_snapshot = true

  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.name
  vpc_security_group_ids = [ aws_security_group.db-sg.id ]
}


resource "aws_security_group" "db-sg" {
  name        = "${var.user_name}-db-sg"
  description = "security group for rds instnace"
  vpc_id      = aws_vpc.test.id

  ingress {
    description = "Allow TLS"
    from_port = 0
    to_port = 0
    security_groups = [ aws_security_group.instance-sg.id ]
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.user_name}-db-sg"
  }
}