output "vpc" {
  value = module.vpc
}

output "eip" {
  value = aws_eip.eip
}

output "ec2_instance" {
  value = aws_instance.instance
}