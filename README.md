# Consul Cluster with Vault CA - Venafi Demo

## How to use this repo
This repo has the following folder structure:

* [vpc](https://github.com/dcallao/venafi-demo/tree/master/vpc): This folder contains terraform code to stand up a AWS VPC with 3 private and 3 public subnets, in 3 AZ's on `us-west-2` region. This was built with the `terraform-aws-vpc` module - for more info click [here](https://github.com/terraform-aws-modules/terraform-aws-vpc)

* [consul-ec2](https://github.com/dcallao/venfi-demo/tree/master/consul-ec2): This folder contains terraform code to stand up a 2-node Consul cluster on AWS, attached to an ASG and a classic ELB. This was built with the `terraform-aws-consul` module - for mode info click [here](https://github.com/hashicorp/terraform-aws-consul)

* [vault-s3-ec2](https://github.com/dcallao/venafi-demo/tree/master/vault-s3-ec2): This folder contains terraform code to stand up a 1-node Vault cluster on AWS, attached to an ASG, and a classic. This was built with the `terraform-aws-vault` module - for more info click [here](https://github.com/hashicorp/terraform-aws-vault)

## How to stand up the demo clusters
This demo is broken up into 3 stacks: VPC, Consul Cluster, and Vault Cluster. You should stand up the stacks in this order.

1. VPC Stack

This will stand up a new VPC, subnets, route table, DHCP options, gateway, and an S3 endpoint. DHCP options is enabled for consul service domain `service.consul` along its DNS servers `"127.0.0.1" and "20.10.0.2"` - this needs to be enabled for Consul cluster DNS communication. Run terraform : `terraform init`, `terraform plan`, and `terraform apply` in the the `vpc` directory.

2. Consul Stack

This will stand up a new Consul cluster. To deploy:
- Create a Consul AMI using a Packer template.  Here is an [example Packer template](https://github.com/dcallao/venafi-demo/tree/master/consul-ec2/consul-ami/consul.json).
- Fill in the necessary variables in `variables.tf` (i.e AMI ID, VPC ID, and subnets IDs)
- Run terraform : `terraform init`, `terraform plan`, and `terraform apply` in the `consul-ec2` directory
- Follow the Outputs screen on the terminal window. Copy + paste HTTP link to the Consul ELB created by Terraform.

3. Vault Stack

This will stand up a new Vault cluster. To deploy:
- Create a Vault AMI using a Packer template.  Here is an [example Packer template](https://github.com/dcallao/venafi-demo/tree/master/vault-s3-ec2/vault-ami/vault-consul.json).
- Fill in the necessary variables in `variables.tf` (i.e AMI ID, VPC ID, and subnets IDs)
- Run terraform : `terraform init`, `terraform plan`, and `terraform apply` in the `vault-s3-ec2` directory
- Follow the Outputs screen on the terminal window. Copy + paste HTTPS link to the Vault ELB created by Terraform.
- Check on the HTTP link to the Consul ELB and verify that the Vault server has been properly registered within the Consul dashboard
- Initialize the Vault server with seal and master keys. Copy those keys in a safe location.

## How to set up Vault as a CA for Consul
Once the Consul and Vault clusters are stood up, follow these steps to set up Vault as a CA server:

1. Set up Vault PKI Secrets Engine

Please follow the steps described in this [guide](https://www.vaultproject.io/docs/secrets/pki/index.html)

The Consul clusters in this demo have been loaded with the TLS keys used to talk with the Vault cluster. Those keys are saved under `/opt/consul/tls` path in the Consul AMI. A `json` [payload](https://github.com/dcallao/venafi-demo/tree/master/consul-ec2/consul-ami/connect-payload.json) file is also saved under `/home/ubuntu/payload.json`.

2. Load the Consul Connect with Vault CA configs

Once the the PKI engine is set up, you will need a user token generated by Vault for Consul Connect to talk with Vault. Insert that token in `/home/ubuntu/payload.json` the follow these steps:

- SSH into one of the Consul servers in the cluster
- Check the current Consul Connect configuration and verify Consul Connect is enabled and CA server is set to Consul CA: `curl http://localhost:8500/v1/connect/ca/configuration | jq`
- Check the CA root certs and verify that Consul CA has generated a root cert to itself: `curl localhost:8500/v1/connect/ca/roots | jq`
- Check if Vault has registered itself with Consul DNS: `dig @127.0.0.1 -p 8600 vault.service.consul SRV`
- Check on the Consul cluster peers and verify that there is a leader and a follower: `consul operator raft list-peers`
- Load the new Consul Connect configuration: `consul connect ca set-config -config-file /home/ubuntu/payload.json`
- Verify the new Consul Connect config with a Vault as CA: `consul connect ca get-config | jq`
- Verify that Vault has generated a new root CA to the Consul cluster: `curl localhost:8500/v1/connect/ca/roots | jq`
- Verify that same root CA has been propagated across both Consul servers in the cluster. Run this command in both Consul servers: `curl localhost:8500/v1/connect/ca/roots | jq`

3. Vault PKI backend

At this point you should be able to verify within Vault's PKI root path under "Certificates" that a root cert has been generated and provided to the Consul cluster. You may use Venafi's PKI backend plug-in within Vault to generate certs to Consul. See https://github.com/Venafi/vault-pki-backend-venafi


