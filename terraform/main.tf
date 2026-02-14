provider "aws" {
  region = var.aws_region
}

# Use 2 AZs for availability
data "aws_availability_zones" "available" {
  state = "available"
}

# Always use exactly 2 AZs (stable & explicit)
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

########################
# VPC + Networking
########################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "tf-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "tf-igw" }
}

# Public subnets (for ALB + NAT)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "tf-public-${count.index + 1}" }
}

# Private subnets (for EC2/ASG)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "tf-private-${count.index + 1}" }
}

# Public route table -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "tf-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

########################
# NAT Gateways (HIGH AVAILABILITY: 1 per AZ)
########################

# 2 Elastic IPs (one per NAT)
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
  tags   = { Name = "tf-nat-eip-${count.index + 1}" }
}

# 2 NAT Gateways (one in each public subnet)
resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "tf-nat-${count.index + 1}" }

  depends_on = [aws_internet_gateway.igw]
}

# 2 Private route tables (one per AZ)
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  tags   = { Name = "tf-private-rt-${count.index + 1}" }
}

# Each private route table -> NAT in the SAME AZ
resource "aws_route" "private_outbound" {
  count                  = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

# Associate each private subnet to its own private route table
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

########################
# Security Groups
########################

# ALB SG: allow HTTP from the internet
resource "aws_security_group" "alb_sg" {
  name        = "tf-alb-sg"
  description = "ALB allows HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 SG: allow HTTP ONLY from ALB SG
resource "aws_security_group" "ec2_sg" {
  name        = "tf-ec2-sg"
  description = "EC2 allows HTTP only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################
# ALB + Target Group
########################

resource "aws_lb" "app" {
  name               = "tf-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public[0].id, aws_subnet.public[1].id]

  tags = { Name = "tf-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "tf-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

########################
# Auto Scaling Group (replaces EC2 count)
########################

resource "aws_launch_template" "web" {
  name_prefix   = "tf-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Launch Template requires base64 for user_data
  user_data = base64encode(file("../scripts/user_data.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "tf-private-nginx"
    }
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "tf-web-asg"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.private[0].id, aws_subnet.private[1].id]

  # Attach ASG instances to the ALB target group
  target_group_arns = [aws_lb_target_group.tg.arn]

  # Replace unhealthy instances based on ALB health checks
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "tf-private-nginx"
    propagate_at_launch = true
  }
}