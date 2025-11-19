provider "aws" {
  region = "us-east-2"
}

# ---------------- VPC ----------------
resource "aws_vpc" "aditya_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "vpc_addi"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.aditya_vpc.id
  tags = {
    Name = "tf-igw"
  }
}

# ---------------- Subnets ----------------
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2b"
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-2a"
  tags = {
    Name = "application-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-2b"
  tags = {
    Name = "application-private-subnet-2"
  }
}

# ---------------- NAT Gateway ----------------
resource "aws_eip" "nat_eip" {
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "tf-natgw"
  }
}

# ---------------- Route Tables ----------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.aditya_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "tf-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.aditya_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "tf-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# ---------------- Security Groups ----------------
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.aditya_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name   = "application-sg"
  vpc_id = aws_vpc.aditya_vpc.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "application-sg"
  }
}

resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.aditya_vpc.id
  ingress {
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
  tags = {
    Name = "bastion-sg"
  }
}

#-------------- Generate key -------------
resource "tls_private_key" "redis_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "redis_keypair" {
  key_name   = "redis-key"
  public_key = tls_private_key.redis_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.redis_key.private_key_pem
  filename = "${path.module}/redis-key.pem"
}

# ---------------- Bastion Host ----------------
resource "aws_instance" "bastion" {
  ami                         = "ami-0d9a665f802ae6227"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  key_name                    = "redis-key"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "bastion-host"
  }
}

# ---------------- ALB ----------------
resource "aws_lb" "alb" {
  name               = "tf-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  security_groups    = [aws_security_group.alb_sg.id]
  tags               = { Name = "tf-alb" }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "tg-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.aditya_vpc.id
  health_check {
    path              = "/"
    matcher           = "200"
    interval          = 30
    healthy_threshold = 2
  }
  tags = { Name = "tg-app" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ---------------- Launch Template + ASG ----------------
resource "aws_launch_template" "app_lt" {
  name                   = "app-template"
  image_id               = "ami-0d9a665f802ae6227"
  instance_type          = "t3.micro"
  key_name               = "redis-key"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e
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

  #---- tags for instance ---
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-server"
    }
  }
}


# ---------------- Auto Scaling Group ----------------
resource "aws_autoscaling_group" "app_asg" {
  name = "app-asg"
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  force_delete              = true

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}

# ---------------- Auto Scaling Target Tracking Policy ----------------
resource "aws_autoscaling_policy" "target_tracking_cpu" {
  name                   = "target-tracking-cpu-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }

  estimated_instance_warmup = 180
}


# ---------------- Redis Instances ----------------


# ---------------- Network ACL ----------------
resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.aditya_vpc.id
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  egress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
  }
  ingress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
  }
  tags = {
    Name = "private-nacl"
  }
}

# ---------------- Outputs ----------------
output "vpc_id" {
  value = aws_vpc.aditya_vpc.id
}
output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
