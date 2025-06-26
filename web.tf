# Create ALB
resource "aws_alb" "web_alb" {
  name                       = "wordpress-lb"
  internal                   = false
  load_balancer_type         = "application"
  enable_deletion_protection = false
  subnets                    = [for subnet in aws_subnet.web_subnets : subnet.id]
  security_groups            = [aws_security_group.wordpress_app_sg.id]

  tags = {
    Name        = "wordpress-lb"
    CreatedBy   = "Terraform"
  }
}

# Create AutoScaling Target Group
resource "aws_alb_target_group" "web_alb_tg" {
  name        = "wordpress-app-tg"
  port        = 80
  protocol    = "HTTP" 
  vpc_id      = aws_vpc.main_vpc.id

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-499" # Allow any HTTP status code in the range 200-499
  }

  tags = {
    Name        = "wordpress-asg-tg"
    CreatedBy   = "Terraform"
  }
}

# Create Listener
resource "aws_lb_listener" "listener_80" {
  load_balancer_arn = aws_alb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.web_alb_tg.arn
  }
}