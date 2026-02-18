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
