# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = local.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge( {
    Name = local.name
  }, local.tags)
}

# Subnets
# Internet Gateway for Public Subnet
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge({
    Name = "${local.name} Internet Gateway"
  }, local.tags)
}

# EIP for NAT
resource "aws_eip" "nat_eip" {
  vpc = true
  depends_on = [aws_internet_gateway.internet_gateway]
}

# NAT
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)

  tags = merge({
    Name = "${local.name} Nat Gateway"
  }, local.tags)
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(local.public_subnets_cidr_block)
  cidr_block              = element(local.public_subnets_cidr_block, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags                    = merge( {
    Name = "${local.name} Public Subnet ${element(var.availability_zones, count.index)}"
  }, local.tags)
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(local.private_subnets_cidr_block)
  cidr_block              = element(local.private_subnets_cidr_block, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = false
  tags                    = merge({
    Name = "${local.name} Private Subnet ${element(var.availability_zones, count.index)}"
  }, local.tags)
}


# Routing tables to route traffic for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name = "${local.name} Private Route Table"
  }, local.tags)
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name = "${local.name} Public Route Table"
  }, local.tags)
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

# Route for NAT
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

# Route table associations for Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(local.public_subnets_cidr_block)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Route table associations for Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(local.private_subnets_cidr_block)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

# Default Security Group of VPC
resource "aws_security_group" "security_group" {
  name        = "${local.name} Security Group"
  description = "Default SG to allow traffic from the VPC"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [
    aws_vpc.vpc
  ]

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }

  tags = merge({}, local.tags)
}

resource "random_string" "password" {
  length  = 32
  special = false
}


resource "aws_db_subnet_group" "rdssng" {
  name       = "comp851-rds_sg"
  subnet_ids = aws_subnet.private_subnet[*].id

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_security_group" "postgresrds" {
  vpc_id      = aws_vpc.vpc.id
  name        = "rdssecgroup"
  description = "Allow all inbound for Postgres"
  ingress {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_db_instance" "staging" {
  db_name             = "staging"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "15.2"
  skip_final_snapshot    = true
  publicly_accessible    = false
  db_subnet_group_name = aws_db_subnet_group.rdssng.id
  vpc_security_group_ids = [aws_security_group.postgresrds.id]
  username               = "comp851"
  password               = "password"
  storage_encrypted    = true
  storage_type = "gp2"
  depends_on = [aws_security_group.postgresrds]
}

# Craete s3 bucket in new vpc

resource "aws_s3_bucket" "comp851-datamigration" {
  bucket        = "comp851-datamigration"  # Specify the desired bucket name
  force_destroy = false

  lifecycle {
    ignore_changes = [bucket]
  }

  # Tags and other configurations can remain the same as your original code
  tags = {
    "Environment" : "PROD"
    "Project" : "Infrastructure"
  }
}

resource "aws_s3_bucket_public_access_block" "datamigration" {
  bucket                  = aws_s3_bucket.comp851-datamigration.id
  block_public_acls       = false
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_ownership_controls" "datamigration" {
  bucket = aws_s3_bucket.comp851-datamigration.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "datamigration" {
  bucket = aws_s3_bucket.comp851-datamigration.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datamigration" {
  bucket = aws_s3_bucket.comp851-datamigration.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# resource "aws_security_group" "sshsgp" {
#   vpc_id      = aws_vpc.vpc.id
#   # Allow SSH access from your IP address (replace with your IP)
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # Replace with your IP address
#   }
#   tags {
#         Name = "ssh-allowed"
#       }
# }

# resource "aws_instance" "web1" {
#     ami = "${lookup(var.AMI, var.AWS_REGION)}"
#     instance_type = "t2.micro"    # VPC
#     subnet_id = "${aws_subnet.prod-subnet-public-1.id}"    # Security Group
#     vpc_security_group_ids = ["${aws_security_group.ssh-allowed.id}"]    # the Public SSH key
#     key_name = "${aws_key_pair.london-region-key-pair.id}"    # nginx installation   
#     connection {
#         user = "${var.EC2_USER}"
#         private_key = "${file("${var.PRIVATE_KEY_PATH}")}"
#     }
# }// Sends your public key to the instance
# resource "aws_key_pair" "london-region-key-pair" {
#     key_name = "london-region-key-pair"
#     public_key = "${file(var.PUBLIC_KEY_PATH)}"
# }