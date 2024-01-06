locals {
  cidr_block    = "10.0.0.0/16"
  cidr_subnet   = cidrsubnets(local.cidr_block, 8)[0]
  ip            = jsondecode(data.http.ip.response_body).ip # Get ip from http data
  instance_type = "t3.small"
}

data "aws_region" "current" {} # need region for vpc endpoint

data "http" "ip" { # get local IP for security groups
  url = "https://api.ipify.org?format=json"
  request_headers = {
    Accept = "application/json"
  }
}

data "aws_ami" "amzlinux" { # get amazon linux ami for current region
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"] # amazon linux 2023
    # values = ["amzn2-ami-kernel-5.10*-x86_64-gp2"] # amazon linux 2
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "local_file" "rsa" { # get local rsa public key for temporary keypair
  filename = pathexpand("~/.ssh/id_rsa.pub")
}

resource "aws_vpc" "socksbox" {
  cidr_block           = local.cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "socksbox"
  }
}

resource "aws_subnet" "socksbox" {
  vpc_id     = aws_vpc.socksbox.id
  cidr_block = local.cidr_subnet

  tags = {
    Name = "socksbox"
  }
}

resource "aws_internet_gateway" "socksbox" {
  vpc_id = aws_vpc.socksbox.id

  tags = {
    Name = "socksbox"
  }
}

resource "aws_route_table" "socksbox" {
  vpc_id = aws_vpc.socksbox.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.socksbox.id
  }

  tags = {
    Name = "socksbox"
  }
}

resource "aws_route_table_association" "socksbox_public" {
  subnet_id      = aws_subnet.socksbox.id
  route_table_id = aws_route_table.socksbox.id
}

resource "aws_security_group" "socksbox" {
  name   = "SSH"
  vpc_id = aws_vpc.socksbox.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "socksbox"
  }
}

resource "aws_key_pair" "socksbox" {
  key_name   = "socksbox-key"
  public_key = data.local_file.rsa.content
}

resource "aws_instance" "socksbox" {
  ami           = data.aws_ami.amzlinux.id
  instance_type = local.instance_type
  key_name      = aws_key_pair.socksbox.id

  subnet_id                   = aws_subnet.socksbox.id
  vpc_security_group_ids      = [aws_security_group.socksbox.id]
  associate_public_ip_address = true
  depends_on = [
    aws_internet_gateway.socksbox
  ]
  root_block_device {
    volume_size           = "10"
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  tags = {
    "Name" : "socksbox"
  }
  provisioner "local-exec" {
    when = destroy
    command = "./killtunnel.sh"
    on_failure = continue
  }
}


output "socksbox_ip" {
  value = aws_instance.socksbox.public_ip
}

output "socksbox_url" {
  value = "http://${aws_instance.socksbox.public_dns}"
}

output "instructions" {
  value = "Run ./starttunnel.sh"
}