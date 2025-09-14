locals {
  prefix = var.name_prefix
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "aws_ecr_authorization_token" "repository" {
  registry_id = split(".", var.aws_ecr_url)[0]
}

data "aws_ecr_image" "image" {
  repository_name = split(":", var.aws_ecr_image)[0]
  image_tag       = split(":", var.aws_ecr_image)[1]
}

provider "docker" {
  disable_docker_daemon_check = true
  host                        = "ssh://ubuntu@${var.aws_instance_public_ip}"
  ssh_opts = [
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "-i", var.ssh_private_key_path
  ]

  registry_auth {
    address  = var.aws_ecr_url
    username = "AWS"
    password = data.aws_ecr_authorization_token.repository.password
  }
}

#################################################################################################
# Docker Image Configuration
#################################################################################################

resource "docker_image" "image" {
  name = "${var.aws_ecr_url}/${var.aws_ecr_image}"
  pull_triggers = [
    data.aws_ecr_image.image.id,
    var.aws_instance_id
  ]
}

resource "docker_container" "container" {
  name  = "${local.prefix}_server"
  image = docker_image.image.image_id

  volumes {
    host_path      = "/data/minecraft/world"
    container_path = "/data/world"
  }

  dynamic "ports" {
    for_each = var.docker_container_ports
    iterator = port
    content {
      internal = port.key
      external = port.value
    }
  }
}