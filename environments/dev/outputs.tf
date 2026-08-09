output "mac_dev_public_ip" {
  value = module.ec2_mac_dev.public_ip
}

output "mac_dev_ssh_tunnel_command" {
  value = module.ec2_mac_dev.ssh_tunnel_command
}