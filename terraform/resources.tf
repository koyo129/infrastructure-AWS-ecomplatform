provider "aws" {
  region = var.aws_region
}

# 2 AZs for availability
data "aws_availability_zones" "available" {
  state = "available"
}

# 2 AZs
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}