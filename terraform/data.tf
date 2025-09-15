#################################################################################################
# ECR Data
#################################################################################################

data "aws_ecr_repository" "ecr_repository" {
  name        = split(":", var.aws_ecr_image)[0]
  registry_id = split(".", var.aws_ecr_url)[0]
}

#################################################################################################
# EC2 Data
#################################################################################################

data "aws_ec2_spot_price" "spot_price" {
  instance_type     = "t3.nano"
  availability_zone = local.availability_zone

  filter {
    name   = "product-description"
    values = ["Linux/UNIX"]
  }
}

# Reference existing key pair
data "aws_key_pair" "default" {
  key_name = "default"
}

#################################################################################################
# IAM Data
#################################################################################################

data "aws_iam_policy_document" "efs_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]

    resources = [aws_efs_file_system.efs.arn]
  }
}