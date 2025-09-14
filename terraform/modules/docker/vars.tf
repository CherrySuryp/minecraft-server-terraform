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

variable "aws_ecr_url" {
  type = string
}

variable "aws_ecr_image" {
  type = string
}

variable "aws_instance_id" {
  type = string
}

variable "aws_instance_public_ip" {
  type = string
}

variable "docker_container_ports" {
  type = map(any)
}