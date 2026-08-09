output "instance_id" {
  description = "EC2 instance ID of the Mac dev instance."
  value       = aws_instance.mac_dev.id
}

output "host_id" {
  description = "Dedicated Host ID. Subject to Apple's 24-hour minimum allocation."
  value       = aws_ec2_host.mac_dev.id
}

output "public_ip" {
  description = "Public IP of the Mac dev instance."
  value       = aws_instance.mac_dev.public_ip
}

output "ssh_tunnel_command" {
  description = "Run locally, then point a VNC client at localhost:5900."
  value       = "ssh -i <path-to-private-key> -L 5900:localhost:5900 ec2-user@${aws_instance.mac_dev.public_ip}"
}