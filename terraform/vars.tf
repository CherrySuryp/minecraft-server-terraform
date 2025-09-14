variable "name_prefix" {
  type    = string
  default = "mc"
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
  type        = string
  description = "Availability Zone. E.g 'eu-central-1'"
  default     = "eu-central-1"
}

variable "aws_az_postfix" {
  type        = string
  description = "Availability Zone Postfix. E.g: a, b, c"
  default     = "a"
}

variable "aws_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aws_vpc_public_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "aws_ingress_ports" {
  type = map(any)
  default = {
    "22"    = 22,
    "25565" = 25565,
    "25575" = 25575,
  }
}

variable "aws_sg_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "aws_ecr_url" {
  type    = string
  default = "982081078573.dkr.ecr.eu-central-1.amazonaws.com"
}

variable "aws_ecr_image" {
  type    = string
  default = "minecraft_server:1.21.1-rev4"
}


variable "aws_ec2_instance_type" {
  type    = string
  default = "a1.xlarge"
}

variable "aws_ec2_ami" {
  type    = string
  default = "ami-0ed1e06189d76073f"
}

variable "aws_ec2_key_name" {
  type    = string
  default = "default"
}

variable "docker_container_ports" {
  type        = map(any)
  description = "Map of type {internal_port: external_port}"
  default = {
    25565 : 25565,
    25575 : 25575,
  }
}
