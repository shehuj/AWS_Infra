output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability Zones in use."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (load balancers only)."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (ECS tasks)."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways, for allow-listing egress with third parties."
  value       = [for eip in aws_eip.nat : eip.public_ip]
}
