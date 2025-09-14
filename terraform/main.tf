module "aws" {
  source = "./modules/aws"

  name_prefix           = var.name_prefix
  ssh_private_key_path  = var.ssh_private_key_path
  aws_access_key        = var.aws_access_key
  aws_secret_key        = var.aws_secret_key
  aws_region            = var.aws_region
  aws_az_postfix        = var.aws_az_postfix
  aws_vpc_cidr          = var.aws_vpc_cidr
  aws_vpc_public_cidr   = var.aws_vpc_public_cidr
  aws_ingress_ports     = var.aws_ingress_ports
  aws_sg_cidr           = var.aws_sg_cidr
  aws_ecr_url           = var.aws_ecr_url
  aws_ecr_image         = var.aws_ecr_image
  aws_ec2_instance_type = var.aws_ec2_instance_type
  aws_ec2_ami           = var.aws_ec2_ami
  aws_ec2_key_name      = var.aws_ec2_key_name
}

module "docker" {
  source = "./modules/docker"

  name_prefix            = var.name_prefix
  ssh_private_key_path   = var.ssh_private_key_path
  aws_access_key         = var.aws_access_key
  aws_secret_key         = var.aws_secret_key
  aws_region             = var.aws_region
  aws_ecr_url            = var.aws_ecr_url
  aws_ecr_image          = var.aws_ecr_image
  aws_instance_id = module.aws.ec2_instance.arn
  aws_instance_public_ip = module.aws.eip.public_ip
  docker_container_ports = var.docker_container_ports
}