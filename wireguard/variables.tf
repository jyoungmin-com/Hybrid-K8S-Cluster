variable "project_name" {
  description = "PROJECT NAME"
  type        = string
  default     = "h8s"
}

variable "vpc_cidr" {
  description = "CIDR BLOCK FOR VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "subnet-1_cidr" {
  description = "SUBNET-1 CIDR"
  type        = string
  default     = "172.31.1.0/24"
}
variable "subnet-2_cidr" {
  description = "SUBNET-2 CIDR"
  type        = string
  default     = "172.31.2.0/24"
}
variable "subnet-3_cidr" {
  description = "SUBNET-3 CIDR"
  type        = string
  default     = "172.31.3.0/24"
}

variable "cluster_services_cidr" {
  description = "cluster services cidr"
  type        = string
  default     = "10.96.0.0/12"
}

variable "pod_cidr" {
  description = "k8s cluster pods cidr"
  type        = string
  default     = "10.42.0.0/16"
}

variable "wireguard_cidr" {
  description = "wireguard vpn tunnel cidr"
  type        = string
  default     = "10.10.0.0/24"
}

variable "master_cidr" {
  description = "on-prem master node cidr"
  type        = string
  default     = "192.168.0.0/24"
}

variable "vpc_name" {
  description = "NAME TAG FOR VPC"
  type        = string
  default     = "h8s-vpc"
}

variable "igw_name" {
  description = "IGW NAME"
  type        = string
  default     = "h8s-igw"
}

variable "ec2_keypair" {
  description = "KEY PAIR FOR EC2"
  type        = string
}

variable "instance_type" {
  description = "EC2 INSTANCE TYPE for WireGuard Hub"
  type        = string
  default     = "t3.small"
}

variable "ec2_volume_size" {
  description = "EC2 VOLUME SIZE"
  type        = number
  default     = 8
}

variable "ec2_volume_type" {
  description = "EC2 VOLUME TYPE"
  type        = string
  default     = "gp3"
}

variable "wireguard_hub_ip" {
  description = "WireGuard hub IP address"
  type        = string
  default     = "10.10.0.1"
}

variable "master_public_key" {
  description = "WireGuard public key of on-premise master node"
  type        = string
  sensitive   = true
}

variable "master_wireguard_ip" {
  description = "Master node IP address"
  type        = string
  default     = "10.10.0.2"
}

variable "master_internal_cidr" {
  description = "Master node internal IP CIDR"
  type        = string
  default     = "192.168.0.0/24"
}

variable "aws_access_key" {
  description = "AWS ACCESS KEY"
  type = string
  sensitive = true
}

variable "aws_secret_access_key" {
  description = "AWS SECRET ACCESS KEY"
  type = string
  sensitive = true
}

variable "igw_route_dest_cidr" {
  description = "TRAFFIC CIDR BLOCK TO GO IGW"
  type        = string
  default     = "0.0.0.0/0"
}

variable "aws_region" {
  description = "AWS REGION"
  type = string
}