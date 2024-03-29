# VPC
output "vpc_id" {
  description = "The ID of the VPC"
  value       =  module.vpc.vpc_id
}

# Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# NAT gateways
output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

# VPC endpoints
output "vpc_endpoint_s3_id" {
  description = "The ID of VPC endpoint for S3"
  value       = module.vpc.vpc_endpoint_s3_id
}
output "vpc_endpoint_ec2_id" {
  description = "The ID of VPC endpoint for EC2"
  value       = module.vpc.vpc_endpoint_ec2_id
}
