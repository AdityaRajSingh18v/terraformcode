resource "aws_lb" "alb" {
  name               = "tf-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [var.alb_sg_id]
  tags               = { Name = "tf-alb" }
}


resource "aws_lb_target_group" "tg" {
  name     = "tg-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path              = "/"
    matcher           = "300"
    interval          = 30
    healthy_threshold = 3
  }
  tags = { Name = "tg-app" }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn 
    }
}

resource "aws_launch_template" "lt" {
  name                   = "app-template"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [var.app_sg_id]
  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install redis-server -y
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    echo "Redis installation completed successfully on Ubuntu" >> /home/ubuntu/redis_install.log
  EOF
  )
  tags = {
    Name = "app-template"
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-server"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  name = "app-asg"
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.private_subnets
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns   = [aws_lb_target_group.tg.arn]
  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}


resource "aws_autoscaling_policy" "target_tracking_cpu" {
  name                   = "target-tracking-cpu-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }

  estimated_instance_warmup = 180
}
