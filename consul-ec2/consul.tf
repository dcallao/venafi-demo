# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A CONSUL CLUSTER IN AWS
# These templates show an example of how to use the consul-cluster module to deploy Consul in AWS. We deploy two Auto
# Scaling Groups (ASGs): one with a small number of Consul server nodes and one with a larger number of Consul client
# nodes. Note that these templates assume that the AMI you provide via the ami_id input variable is built from
# the examples/consul-ami/consul.json Packer template.
# ---------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 0.12"
}

# Configure the AWS Provider
provider "aws" {
  region                      = "us-west-2"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTOMATICALLY LOOK UP THE LATEST PRE-BUILT AMI
# This repo contains a CircleCI job that automatically builds and publishes the latest AMI by building the Packer
# template at /examples/consul-ami upon every new release. The Terraform data source below automatically looks up the
# latest AMI so that a simple "terraform apply" will just work without the user needing to manually build an AMI and
# fill in the right value.
#
# !! WARNING !! These exmaple AMIs are meant only convenience when initially testing this repo. Do NOT use these example
# AMIs in a production setting because it is important that you consciously think through the configuration you want
# in your own production AMI.
#
# NOTE: This Terraform data source must return at least one AMI result or the entire template will fail. See
# /_ci/publish-amis-in-new-account.md for more information.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_ami" "consul" {
  most_recent = true

  # If we change the AWS Account in which test are run, update this value.
  owners = ["562637147889"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "is-public"
    values = ["true"]
  }

  filter {
    name   = "name"
    values = ["consul-ubuntu-*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "consul_servers" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.0.1"
  source = "./modules/consul-cluster"

  cluster_name  = "${var.cluster_name}-server"
  cluster_size  = var.num_servers
  instance_type = "t2.micro"
  spot_price    = var.spot_price

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = var.cluster_tag_key
  cluster_tag_value = var.cluster_name

  ami_id    = "${var.ami_id == null ? data.aws_ami.consul.image_id : var.ami_id}"
  user_data = "${data.template_file.user_data_server.rendered}"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = var.subnet_ids

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = var.ssh_key_name

  tags = [
    {
      key                 = "Team"
      value               = "Partner Alliances SE Team"
      propagate_at_launch = true
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL SERVER EC2 INSTANCE WHEN IT'S BOOTING
# This script will configure and start Consul
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data_server" {
  template = file("${path.module}/userdata/user-data-server.sh")

  vars = {
    cluster_tag_key   = var.cluster_tag_key
    cluster_tag_value = var.cluster_name
  }
}

# Create a new load balancer
resource "aws_elb" "consul_elb" {
  name    = var.cluster_name
  subnets = var.subnet_ids

  listener {
    instance_port     = 8500
    instance_protocol = "TCP"
    lb_port           = 80
    lb_protocol       = "TCP"
  }

  health_check {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:8500"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 60
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = var.cluster_name
  }

}

# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "asg_attachment_consul" {
  autoscaling_group_name = module.consul_servers.asg_name
  elb                    = aws_elb.consul_elb.id
}


# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY CONSUL IN THE DEFAULT VPC AND SUBNETS
# Using the default VPC and subnets makes this example easy to run and test, but it means Consul is accessible from the
# public Internet. For a production deployment, we strongly recommend deploying into a custom VPC with private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = var.vpc_id == null ? true : false
  id      = var.vpc_id
}

data "aws_region" "current" {
  name = var.region
}



