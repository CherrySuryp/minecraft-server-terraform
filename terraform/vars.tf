variable "name_prefix" {
  type    = string
  default = "mc-server"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name_prefix))
    error_message = "only alphanumeric characters and hyphens allowed"
  }
}

#################################################################################################
# AWS General Vars
#################################################################################################

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

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must contain only lowercase letters, numbers, and hyphens (e.g., 'us-west-2', 'eu-central-1')"
  }
}

variable "aws_az_postfix" {
  type        = string
  description = "Availability Zone Postfix. E.g: a, b, c"
  default     = "a"

  validation {
    condition     = can(regex("^[a-c]$", var.aws_az_postfix))
    error_message = "AWS AZ postfix must be a single letter: a, b, or c"
  }
}

#################################################################################################
# VPC Vars
#################################################################################################

variable "aws_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.aws_vpc_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.0.0.0/16)"
  }
}

variable "aws_vpc_public_cidr" {
  type    = string
  default = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.aws_vpc_public_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.0.1.0/24)"
  }
}

variable "aws_vpc_sg_inbound_rules" {
  type = object({
    ports    = map(number)
    protocol = string
    cidr     = string
  })
  default = {
    ports    = { 25565 = 25565 }
    protocol = "tcp"
    cidr     = "0.0.0.0/0"
  }
}

variable "aws_vpc_sg_outbound_rules" {
  type = object({
    ports    = map(number)
    protocol = string
    cidr     = string
  })
  default = {
    ports    = { 0 = 65535 }
    protocol = "-1"
    cidr     = "0.0.0.0/0"
  }
}

#################################################################################################
# ECS Vars
#################################################################################################

variable "aws_ecs_task_cpu" {
  type        = number
  description = "Amount of vCPUs"
  default     = 2
  validation {
    condition     = var.aws_ecs_task_cpu > 0 && var.aws_ecs_task_cpu <= 10
    error_message = "Amount of vCPUs should be between 1 and 10"
  }
}

variable "aws_ecs_task_memory" {
  type        = number
  description = "Amount of container RAM in GB"
  default     = 4
  validation {
    condition     = var.aws_ecs_task_memory >= 4
    error_message = "Amount of RAM memory should be >= 4"
  }
}

variable "aws_ecs_task_port_mappings" {
  type = map(any)
  default = {
    25565 : 25565,
    25575 : 25575,
  }
}

variable "aws_ecs_task_env_vars" {
  type = any
}

#################################################################################################
# ECR Vars
#################################################################################################

variable "aws_ecr_url" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com$", var.aws_ecr_url))
    error_message = "ECR URL must be in format '{account-id}.dkr.ecr.{region}.amazonaws.com' (e.g., '123456789012.dkr.ecr.us-west-2.amazonaws.com')"
  }
}

variable "aws_ecr_image" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9_-]+:[a-zA-Z0-9._-]+$", var.aws_ecr_image))
    error_message = "ECR image must be in format 'repository:tag' with valid characters (e.g., 'minecraft_server:1.21.1-r1')"
  }
}