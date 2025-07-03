output "vpc_id" {
  description = "VPC ID"
  value = aws_vpc.vpc.id
}

output "subnet1" {
  description = "SUBNET 1 ID"
  value = aws_subnet.subnet1.id
}
output "subnet2" {
  description = "SUBNET 2 ID"
  value = aws_subnet.subnet2.id
}

output "wireguard_eip_public_ip" {
  description = "The public Elastic IP of the WireGuard EC2 instance"
  value       = aws_eip.eip.public_ip
}

