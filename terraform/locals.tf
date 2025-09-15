locals {
  prefix = var.name_prefix
  default_tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
  availability_zone = "${var.aws_region}${var.aws_az_postfix}"
  ecr_image         = "${var.aws_ecr_url}/${var.aws_ecr_image}"
}
