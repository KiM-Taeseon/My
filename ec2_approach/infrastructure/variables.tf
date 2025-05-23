### infrastructure/variables.tf
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "config_bucket_name" {
  description = "Name of the S3 bucket for Terraform configurations"
  type        = string
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-locks"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0f61efb6cfbcc18a4" # Amazon Linux 2 AMI (HVM) - adjust for your region
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Key pair name for SSH access to the EC2 instance"
  type        = string
  default     = "terraform_runner_key"
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

variable "webhook_allowed_cidr" {
  description = "CIDR blocks allowed for webhook access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}