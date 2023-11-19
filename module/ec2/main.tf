# Define the security group for jump server.
resource "aws_security_group" "jump_server_ec2" {
  name   = "Security group for jump server"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH inbound traffic"
  }

   ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "HTTPS"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port        = 0
    protocol         = "-1"
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow all outbound traffic"
  }

  tags = merge({
    Name : "Security group for jump server"
  }, local.tags)
}

# Define the ec2 instance
resource "aws_instance" "jump_server" {
  count                       = 1
  instance_type               = local.instance_type
  ami                         = local.instance_ami
  associate_public_ip_address = true
  hibernation                 = false
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = setunion([aws_security_group.jump_server_ec2.id], local.security_group_ids)
  key_name                    = "jumpkey-ec2"
}

resource "aws_key_pair" "jumpkey-ec2" {
    key_name = "jumpkey-ec2"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC8+HsYXWr1XWfcRqKPYo0+KUZRqfCBW0UvCDXt9TIHL9l9NKnzvtN+LtMTaLx6xKQErv+X3sMNG2DVfgLWxCRTWWD9JaC4Hd+wKvul61pFE/ugsJ9uYzpecWBuIGjkz6GVeoaGwQ/nm0TQ8unF7XK6Vi8IA8xS+xITpsEln4bpjpGrJZP1BYsjpmKO0kJzwAiiqoBLHkzA4geML/tWkjv5vgsV8yyjKVY6de55VkcEAFfY2aP1rfoFaj3/xtq3Y75z6/ct4uziMSgtRaOPJlkxLK1sIQTxSWxq6o4VnrR8dzONLxyI9s3/UHIp2qtK+ABTjfkc1gusnx//dGoIx3hyVEKVgBZkx1dT/hrGPDs+utlzYifL5LmEeaggVm33edlBaofmUT9XvcyLr6zsIdMMI9f1EtmI6nMn33JTf87z1RaZk4jt5W/lVxZ6Hjh3XrX3esd7MZmCFRwKfj8Yx0ikdDiTHt9ZCrZoZWzcY21+r6+9ropOwchM7SUbeiRhOV8= vinod@Teddy"
    #public_key = "${file(var.PUBLIC_KEY_PATH)}"
}