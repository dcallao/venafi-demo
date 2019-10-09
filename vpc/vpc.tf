# Configure the AWS Provider
provider "aws" {
  region                      = "us-west-2"
  profile                     = "default"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "This is a test vpc"

  cidr = "20.10.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["20.10.1.0/24", "20.10.2.0/24", "20.10.3.0/24"]
  public_subnets  = ["20.10.10.0/24", "20.10.20.0/24", "20.10.30.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dhcp_options              = true
  dhcp_options_domain_name         = "service.consul"
  dhcp_options_domain_name_servers = ["127.0.0.1", "20.10.0.2"]

  # VPC endpoint for S3
  enable_s3_endpoint = true

  # Tags
  public_subnet_tags = {
    Name = "test-vpc-public-subnet"
  }

  private_subnet_tags = {
    Name = "test-vpc-private-subnet"
  }

  igw_tags = {
    Name = "test-vpc-igw"
  }

  tags = {
    Owner       = "dcallao"
    Team        = "HashiCorp Partner Alliances"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "test-vpc"
  }
}

