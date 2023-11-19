output "jump-server-security-group-id" {
  value = aws_security_group.jump_server.id
}

output "bastion_public_ip" {
  value = aws_instance.jump_server[0].public_ip
}