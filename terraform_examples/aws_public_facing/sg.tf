resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = "443"
  protocol          = "HTTPS"

  # Replace this ARN with your ACM cert
  certificate_arn   = "arn:aws:acm:region:account:certificate/your-cert-id"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3_endpoint.id
  }
}

resource "aws_lb_target_group" "s3_endpoint" {
  name        = "s3-endpoint-tg"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    path                = "/"
    protocol            = "HTTPS"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
