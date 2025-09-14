output "minecraft_instance_public_ip" {
  value = module.aws.eip.public_ip
}