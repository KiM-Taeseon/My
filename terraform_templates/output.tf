output "lb_dnsname" {
  value = aws_lb.lb.dns_name
}

output "private_key" {
  value = tls_private_key.private_key.private_key_pem
  sensitive = true
}