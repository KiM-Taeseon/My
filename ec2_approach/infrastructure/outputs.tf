# Updated infrastructure/outputs.tf to include Project Builder

# Terraform Runner outputs
output "instance_id" {
  description = "ID of the Terraform Runner EC2 instance"
  value       = aws_instance.terraform_runner.id
}

output "instance_public_ip" {
  description = "Public IP address of the Terraform Runner EC2 instance"
  value       = aws_eip.terraform_eip.public_ip
}

output "webhook_endpoint" {
  description = "Endpoint URL for the Terraform webhook"
  value       = "http://${aws_eip.terraform_eip.public_ip}:8080/run-terraform"
}

# Project Builder outputs
output "project_builder_instance_id" {
  description = "ID of the Project Builder EC2 instance"
  value       = aws_instance.project_builder.id
}

output "project_builder_public_ip" {
  description = "Public IP address of the Project Builder EC2 instance"
  value       = aws_eip.project_builder_eip.public_ip
}

output "project_builder_endpoint" {
  description = "Endpoint URL for the Project Builder webhook"
  value       = "http://${aws_eip.project_builder_eip.public_ip}:8081/build-project"
}

# Shared infrastructure outputs
output "state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "config_bucket" {
  description = "S3 bucket for Terraform configurations"
  value       = aws_s3_bucket.terraform_configs.bucket
}

# Service endpoints summary
output "service_endpoints" {
  description = "Summary of all service endpoints"
  value = {
    terraform_runner    = "http://${aws_eip.terraform_eip.public_ip}:8080/run-terraform"
    project_builder     = "http://${aws_eip.project_builder_eip.public_ip}:8081/build-project"
    project_builder_health = "http://${aws_eip.project_builder_eip.public_ip}:8081/health"
  }
}