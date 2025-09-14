provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

locals {
  prefix = var.name_prefix
  default_tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
  scripts = {
    install_dependencies = {
      local_path  = "${path.module}/scripts/install-dependencies.sh"
      remote_path = "/home/ubuntu/install-dependencies.sh"
      inline = [
        "chmod +x /home/ubuntu/install-dependencies.sh",
        "sudo bash /home/ubuntu/install-dependencies.sh",
      ]
    }
    configure_docker = {
      local_path  = "${path.module}/scripts/configure-docker.sh"
      remote_path = "/home/ubuntu/configure-docker.sh"
      inline = [
        "ssh chmod +x /home/ubuntu/configure-docker.sh",
        "sudo bash /home/ubuntu/configure-docker.sh",
        "sudo mkdir -p /home/ubuntu/.docker /root/.docker",
        "sudo chown ubuntu:ubuntu /home/ubuntu/.docker",
        "echo '${jsonencode({ "credHelpers" : { (var.aws_ecr_url) : "ecr-login" } })}' | sudo tee /home/ubuntu/.docker/config.json > /dev/null",
        "sudo cp /home/ubuntu/.docker/config.json /root/.docker/config.json",
      ]
    }
    configure_ebs_volume = {
      local_path  = "${path.module}/scripts/configure-ebs-volume.sh"
      remote_path = "/home/ubuntu/configure-ebs-volume.sh"
      inline = [
        "chmod +x /home/ubuntu/configure-ebs-volume.sh",
        "sudo bash /home/ubuntu/configure-ebs-volume.sh",
      ]
    }
  }
}


#################################################################################################
# VPC Configuration
#################################################################################################

# TODO: Add dynamic AMI resolution

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.prefix}_vpc"
  cidr = var.aws_vpc_cidr

  azs            = ["${var.aws_region}${var.aws_az_postfix}"]
  public_subnets = [var.aws_vpc_public_cidr]

  tags = local.default_tags
}

#################################################################################################
# Security Groups Configuration 
#################################################################################################

resource "aws_security_group" "security_group" {
  name   = "${local.prefix}_sg"
  vpc_id = module.vpc.vpc_id

  tags = merge(
    local.default_tags,
    { Name = "${local.prefix}_sg" }
  )
}

resource "aws_security_group_rule" "ingress_sg_rule" {
  type              = "ingress"
  security_group_id = aws_security_group.security_group.id

  for_each    = var.aws_ingress_ports
  from_port   = var.aws_ingress_ports[each.value]
  to_port     = var.aws_ingress_ports[each.value]
  protocol    = "tcp"
  cidr_blocks = var.aws_sg_cidr
}

resource "aws_security_group_rule" "egress_sg_rule" {
  type              = "egress"
  security_group_id = aws_security_group.security_group.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = var.aws_sg_cidr
}

#################################################################################################
# Security Groups Configuration 
#################################################################################################

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.prefix}_ec2_role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.prefix}_ec2_profile"
  role = aws_iam_role.ec2_role.name
}

#################################################################################################
# EC2 Configuration
#################################################################################################

resource "aws_instance" "instance" {
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.security_group.id]

  ami                  = var.aws_ec2_ami
  instance_type        = var.aws_ec2_instance_type
  key_name             = var.aws_ec2_key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
    tags = merge(
      local.default_tags,
      { Name = "${local.prefix}_server_root" }
    )
  }

  tags = merge(
    local.default_tags,
    { Name = "${local.prefix}_server" }
  )
}

resource "aws_eip" "eip" {
  tags = merge(
    local.default_tags,
    { Name = "${local.prefix}_server_ip" }
  )
}

resource "aws_eip_association" "eip_association" {
  instance_id   = aws_instance.instance.id
  allocation_id = aws_eip.eip.id
}

#################################################################################################
# EBS Configuration
#################################################################################################

resource "aws_ebs_volume" "instance_data_volume" {
  availability_zone = "${var.aws_region}${var.aws_az_postfix}"
  size              = 30
  type              = "gp3"
  tags = merge(
    local.default_tags,
    { Name = "${local.prefix}_server_data" }
  )
}

resource "aws_volume_attachment" "instance_data_volume_attachment" {
  device_name = "/dev/sdx"
  volume_id   = aws_ebs_volume.instance_data_volume.id
  instance_id = aws_instance.instance.id
}

#################################################################################################
# Instance Provisioning Configuration
#################################################################################################

locals {
  ssh_connection = {
    type        = "ssh"
    host        = aws_eip.eip.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "2m"
  }
}

resource "null_resource" "install_dependencies" {
  provisioner "file" {
    source      = local.scripts.install_dependencies.local_path
    destination = local.scripts.install_dependencies.remote_path
  }

  provisioner "remote-exec" {
    inline = local.scripts.install_dependencies.inline
  }

  connection {
    type        = local.ssh_connection.type
    host        = local.ssh_connection.host
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    timeout     = local.ssh_connection.timeout
  }

  triggers = { script_hash = sha256(file(local.scripts.install_dependencies.local_path)) }

  depends_on = [
    aws_instance.instance,
    aws_eip.eip,
    aws_eip_association.eip_association,
    aws_volume_attachment.instance_data_volume_attachment,
  ]
}

resource "null_resource" "configure_docker" {
  provisioner "file" {
    source      = local.scripts.configure_docker.local_path
    destination = local.scripts.configure_docker.remote_path
  }

  provisioner "remote-exec" {
    inline = local.scripts.configure_docker.inline
  }

  connection {
    type        = local.ssh_connection.type
    host        = local.ssh_connection.host
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    timeout     = local.ssh_connection.timeout
  }

  triggers = { script_hash = sha256(file(local.scripts.configure_docker.local_path)) }

  depends_on = [
    null_resource.install_dependencies,
  ]
}

resource "null_resource" "configure_ebs_volume" {
  provisioner "file" {
    source      = local.scripts.configure_ebs_volume.local_path
    destination = local.scripts.configure_ebs_volume.remote_path
  }

  provisioner "remote-exec" {
    inline = local.scripts.configure_ebs_volume.inline
  }

  connection {
    type        = local.ssh_connection.type
    host        = local.ssh_connection.host
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    timeout     = local.ssh_connection.timeout
  }

  triggers = { script_hash = sha256(file(local.scripts.configure_ebs_volume.local_path)) }

  depends_on = [
    null_resource.configure_docker,
  ]
}