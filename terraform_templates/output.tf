output "lb_dnsname" {
  value = aws_lb.lb.dns_name
}

output "private_key" {
  value = tls_private_key.private_key.private_key_pem
  sensitive = true
}

output "private_key_filename" {
  value = local_file.private_key_file.filename
}