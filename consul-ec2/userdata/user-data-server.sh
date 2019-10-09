#!/bin/bash
# This script is meant to be run in the User Data of each EC2 Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in server mode. Note that this script assumes it's running in an AMI
# built from the Packer template in examples/consul-ami/consul.json.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# These variables are passed in via Terraform template interplation
/opt/consul/bin/run-consul --server --cluster-tag-key "${cluster_tag_key}" --cluster-tag-value "${cluster_tag_value}"

# Load Consul Connect Vault CA Server Configs
# curl http://localhost:8500/v1/connect/ca/configuration | jq
# curl localhost:8500/v1/connect/ca/roots | jq
# dig @127.0.0.1 -p 8600 consul.service.consul SRV
# consul connect ca get-config | jq
# consul connect ca set-config -config-file /home/ubuntu/payload.json
# consul operator raft list-peers
# consul operator raft remove-peer -address="IP:port"