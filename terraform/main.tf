#################################################################################################
# VPC Configuration
#################################################################################################
locals {
  vpc = {
    name = "${local.prefix}_vpc"
  }
  vpc_sg = {
    name = "${local.prefix}_main_sg"
  }
  eip = {
    name = "${local.prefix}-eip"
  }
  nlb = {
    name = "${local.prefix}-nlb"
  }
  target_group = {
    name = "${local.prefix}-tg"
  }
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.vpc.name
  cidr = var.aws_vpc_cidr

  azs            = [local.availability_zone]
  public_subnets = [var.aws_vpc_public_cidr]

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.default_tags,
    { Name = local.vpc.name }
  )
}

#################################################################################################
# VPC Security Groups Configuration
#################################################################################################

resource "aws_security_group" "main_sg" {
  name   = local.vpc_sg.name
  vpc_id = module.vpc.vpc_id

  depends_on = [module.vpc]

  tags = merge(
    local.default_tags,
    { Name = local.vpc_sg.name }
  )
}

resource "aws_security_group_rule" "ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.main_sg.id

  for_each    = var.aws_vpc_sg_inbound_rules.ports
  from_port   = each.key
  to_port     = each.value
  protocol    = var.aws_vpc_sg_inbound_rules.protocol
  cidr_blocks = [var.aws_vpc_sg_inbound_rules.cidr]
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  security_group_id = aws_security_group.main_sg.id

  for_each    = var.aws_vpc_sg_outbound_rules.ports
  from_port   = each.key
  to_port     = each.value
  protocol    = var.aws_vpc_sg_outbound_rules.protocol
  cidr_blocks = [var.aws_vpc_sg_outbound_rules.cidr]
}

# Security group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${local.prefix}_efs_sg"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.default_tags,
    { Name = "${local.prefix}_efs_sg" }
  )
}

# Allow EFS access from ECS tasks
resource "aws_security_group_rule" "efs_from_ecs" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main_sg.id
  security_group_id        = aws_security_group.efs.id
  description              = "NFS from ECS tasks"
}

# Allow EFS egress
resource "aws_security_group_rule" "efs_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
}

# Security group for EC2 instance
resource "aws_security_group" "ec2_efs_access" {
  name_prefix = "${local.prefix}_ec2_efs_sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.default_tags,
    { Name = "${local.prefix}_ec2_efs_sg" }
  )
}

# Update EFS security group to allow access from EC2 instance
resource "aws_security_group_rule" "efs_from_ec2" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_efs_access.id
  security_group_id        = aws_security_group.efs.id
  description              = "NFS from EC2 instance"
}

#################################################################################################
# IAM Configuration
#################################################################################################
locals {
  iam = {
    task_execution_role_name = "${local.prefix}_ecs_task_execution_role"
    task_role_name           = "${local.prefix}_ecs_task_role"
  }
}

# ECS Task Execution Role (required for Fargate to pull ECR images and write logs)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = local.iam.task_execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.default_tags,
    { Name = local.iam.task_execution_role_name }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (for the application running in the container)
resource "aws_iam_role" "ecs_task_role" {
  name = local.iam.task_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.default_tags,
    { Name = local.iam.task_role_name }
  )
}

# Policy for EFS access
resource "aws_iam_role_policy" "ecs_efs_access_policy" {
  name = "${local.prefix}_efs_access_policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = aws_efs_file_system.efs.arn
      }
    ]
  })
}

#################################################################################################
# Load Balancer Configuration
#################################################################################################

# Elastic IP for persistent public IP
resource "aws_eip" "minecraft_eip" {
  domain = "vpc"

  tags = merge(
    local.default_tags,
    { Name = local.eip.name }
  )

  depends_on = [module.vpc]
}

# Network Load Balancer for persistent IP
resource "aws_lb" "minecraft_nlb" {
  name               = local.nlb.name
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = module.vpc.public_subnets[0]
    allocation_id = aws_eip.minecraft_eip.id
  }

  enable_deletion_protection = false

  tags = merge(
    local.default_tags,
    { Name = local.nlb.name }
  )
}

# Target group for Minecraft server
resource "aws_lb_target_group" "minecraft_tg" {
  count       = length(var.aws_ecs_task_port_mappings)
  name        = "${local.target_group.name}-${count.index}"
  port        = keys(var.aws_ecs_task_port_mappings)[count.index]
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  tags = merge(
    local.default_tags,
    { Name = "${local.target_group.name}-${count.index}" }
  )
}

# Listener for Minecraft traffic
resource "aws_lb_listener" "minecraft_listener" {
  count             = length(var.aws_ecs_task_port_mappings)
  load_balancer_arn = aws_lb.minecraft_nlb.arn
  port              = keys(var.aws_ecs_task_port_mappings)[count.index]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.minecraft_tg[count.index].arn
  }
}

#################################################################################################
# ECS Configuration
#################################################################################################
locals {
  ecs = {
    name = "${local.prefix}_cluster"
  }
  ecs_task = {
    name            = "${local.prefix}_task"
    volume_name     = "${var.name_prefix}_efs_volume"
    cpu_requests    = var.aws_ecs_task_cpu * 1024
    memory_requests = var.aws_ecs_task_memory * 1024
    port_mappings   = var.aws_ecs_task_port_mappings
  }
  ecs_service = {
    name = "${local.prefix}_service"
  }
}


resource "aws_ecs_cluster" "cluster" {
  name = local.ecs.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.default_tags,
    { Name = local.ecs.name }
  )
}

resource "aws_ecs_task_definition" "task" {
  family                   = local.ecs_task.name
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  cpu                = local.ecs_task.cpu_requests
  memory             = local.ecs_task.memory_requests
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn
  network_mode       = "awsvpc"
  ephemeral_storage {
    size_in_gib = 21
  }
  volume {
    name = local.ecs_task.volume_name
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.efs.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.minecraft_data.id
      }
    }
  }

  container_definitions = jsonencode([
    {
      essential       = true
      compatibilities = ["FARGATE"]
      name            = var.name_prefix
      image           = local.ecr_image
      cpu             = local.ecs_task.cpu_requests
      memory          = local.ecs_task.memory_requests
      portMappings    = [for k, v in local.ecs_task.port_mappings : { containerPort = tonumber(k), hostPort = v }]
      mountPoints = [
        {
          sourceVolume  = local.ecs_task.volume_name
          containerPath = "/data/world"
          readOnly      = false
        }
      ]
      environment = [for k, v in var.aws_ecs_task_env_vars : {
        name  = k,
        value = can(tolist(v)) ? join(",", v) : tostring(v)
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "mc-health"]
        interval    = 5
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  skip_destroy = false
  tags = merge(
    local.default_tags,
    { Name = local.ecs_task.name }
  )
}

resource "aws_ecs_service" "service" {
  name            = local.ecs_service.name
  cluster         = aws_ecs_cluster.cluster.id
  force_delete    = true
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0
    base              = 0
  }

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.main_sg.id]
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = var.aws_ecs_task_port_mappings
    content {
      target_group_arn = aws_lb_target_group.minecraft_tg[index(keys(var.aws_ecs_task_port_mappings), load_balancer.key)].arn
      container_name   = var.name_prefix
      container_port   = tonumber(load_balancer.key)
    }
  }

  tags = merge(
    local.default_tags,
    { Name = local.ecs_service.name }
  )

  depends_on = [
    module.vpc,
    aws_efs_file_system.efs,
    aws_efs_mount_target.efs_mount,
    aws_efs_file_system_policy.efs_policy,
    aws_lb_listener.minecraft_listener
  ]
}



#################################################################################################
# EFS Configuration
#################################################################################################
locals {
  efs = {
    name = "${var.name_prefix}_efs"
  }
  efs_access_point = {
    name = "${local.prefix}_minecraft_access_point"
    gid  = 1000
    uid  = 1000
  }
}


resource "aws_efs_file_system" "efs" {
  availability_zone_name = local.availability_zone
  creation_token         = local.efs.name

  throughput_mode  = "bursting"
  performance_mode = "generalPurpose"

  tags = merge(
    local.default_tags,
    { Name = local.efs.name }
  )

  depends_on = [module.vpc]
}

resource "aws_efs_mount_target" "efs_mount" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.public_subnets[0]
  security_groups = [aws_security_group.efs.id]

  depends_on = [module.vpc]
}

resource "aws_efs_access_point" "minecraft_data" {
  file_system_id = aws_efs_file_system.efs.id

  root_directory {
    path = "/data"
    creation_info {
      owner_gid   = local.efs_access_point.gid
      owner_uid   = local.efs_access_point.uid
      permissions = "0755"
    }
  }

  posix_user {
    gid = local.efs_access_point.gid
    uid = local.efs_access_point.uid
  }

  depends_on = [aws_efs_mount_target.efs_mount]

  tags = merge(
    local.default_tags,
    { Name = local.efs_access_point.name }
  )
}

resource "aws_efs_file_system_policy" "efs_policy" {
  file_system_id = aws_efs_file_system.efs.id
  policy         = data.aws_iam_policy_document.efs_policy.json
}

#################################################################################################
# CloudWatch Configuration
#################################################################################################
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${local.prefix}_task"
  retention_in_days = 7

  tags = merge(
    local.default_tags,
    { Name = "/ecs/${local.prefix}_task" }
  )
}

#################################################################################################
# EC2 Instance for EFS Access
#################################################################################################

# EC2 Spot Instance with minimal configuration
resource "aws_spot_instance_request" "efs_access" {
  ami                            = "ami-0444794b421ec32e4"
  instance_type                  = "t3.nano"
  spot_price                     = data.aws_ec2_spot_price.spot_price.spot_price
  wait_for_fulfillment           = true
  spot_type                      = "one-time"
  instance_interruption_behavior = "terminate"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2_efs_access.id]
  associate_public_ip_address = true
  key_name                    = data.aws_key_pair.default.key_name

  # Minimal root volume (8 GB is minimum for Amazon Linux)
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  user_data_base64 = base64encode(templatefile(
    "${path.module}/scripts/ec2-userdata.sh",
    {
      efs_id = aws_efs_file_system.efs.id
      region = var.aws_region
    }
  ))

  tags = merge(
    local.default_tags,
    {
      Name    = "${local.prefix}_efs_access_spot"
      Purpose = "EFS World Data Access"
      Type    = "spot"
    }
  )

  depends_on = [aws_efs_mount_target.efs_mount]
}