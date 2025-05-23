locals {
  key_name = "${var.user_name}-key.pem"
}

# Generate RSA private key
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Write private key to file in current directory
resource "local_file" "private_key_file" {
  content         = tls_private_key.private_key.private_key_pem
  filename        = "${path.module}/${local.key_name}"
  file_permission = "0600"
}
