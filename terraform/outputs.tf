output "minecraft_server_dns" {
  description = "The DNS name of the Network Load Balancer"
  value       = aws_lb.minecraft_nlb.dns_name
}

output "ec2_efs_access_ip" {
  description = "Public IP address of the EC2 spot instance for EFS access"
  value       = aws_spot_instance_request.efs_access.public_ip
}