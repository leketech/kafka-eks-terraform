output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "nat_public_ips" {
  description = "List of public IPs of NAT gateways"
  value       = module.vpc.nat_public_ips
}

output "availability_zones" {
  description = "List of availability zones"
  value       = module.vpc.azs
}