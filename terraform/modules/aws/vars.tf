variable "name_prefix" {
  type = string
}

variable "ssh_private_key_path" {
  default = "~/.aws/default.pem"
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "aws_az_postfix" {
  type = string
}

variable "aws_vpc_cidr" {
  type = string
}

variable "aws_vpc_public_cidr" {
  type = string
}

variable "aws_ingress_ports" {
  type = map(any)
}

variable "aws_sg_cidr" {
  type = list(string)
}

variable "aws_ecr_url" {
  type = string
}

variable "aws_ecr_image" {
  type = string
}


variable "aws_ec2_instance_type" {
  type = string
}

variable "aws_ec2_ami" {
  type = string
}

variable "aws_ec2_key_name" {
  type = string
}