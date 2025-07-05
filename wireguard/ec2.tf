# EC2 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]

}

# Create security group
resource "aws_security_group" "wireguard-sg" {
  name        = "${var.project_name}-wireguard-sg"
  description = "WireGuard VPN SG"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Name = "${var.project_name}-wireguard-sg"
  }

  # test
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create EC2 instance
resource "aws_instance" "wireguard" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.ec2_keypair
  vpc_security_group_ids      = [aws_security_group.wireguard-sg.id]
  associate_public_ip_address = "false"
  subnet_id                   = aws_subnet.subnet1.id
  user_data = templatefile("${path.module}/script/setup.sh", {
    wireguard_hub_ip     = var.wireguard_hub_ip
    master_public_key    = var.master_public_key
    master_wireguard_ip  = var.master_wireguard_ip
    master_internal_cidr = var.master_internal_cidr
    project_name         = var.project_name
    aws_access_key         = var.aws_access_key
    aws_secret_access_key         = var.aws_secret_access_key
  })

  root_block_device {
    volume_size = var.ec2_volume_size
    volume_type = var.ec2_volume_type
    tags = {
      "Name" = "${var.project_name}-wireguard-ec2-volume"
    }
  }

  tags = {
    Name = "${var.project_name}-wireguard-ec2"
  }
}

