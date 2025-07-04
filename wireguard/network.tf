# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = var.vpc_name
  }
}


# Create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.igw_name
  }
}

# Subnet
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-1_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-subnet-1"
    "karpenter.sh/discovery" = "hybrid-cluster"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-2_cidr
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-subnet-2"
    "karpenter.sh/discovery" = "hybrid-cluster"
  }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "${var.project_name}-route-table-public"
  }
}

# Public route table associations
resource "aws_route_table_association" "public1" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public2" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public.id
}

# Public route
resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = var.igw_route_dest_cidr
  gateway_id = aws_internet_gateway.igw.id
}



resource "aws_eip" "eip" {
  instance = aws_instance.wireguard.id
  domain   = "vpc"
  tags = {
    "Name" = "${var.project_name}-wireguard-eip"
  }
}





# -----------------
# SPOT INSTANCE

resource "aws_security_group" "spot-sg" {
  name        = "${var.project_name}-spot-workers"
  description = "Kubernetes Spot workers"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Name = "${var.project_name}-wireguard-sg"
    "karpenter.sh/discovery" = "hybrid-cluster"
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}