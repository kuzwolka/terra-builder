#------------- Locals ----------------------------------------
locals {
  alb_attachments = var.lb_type == "application" ? {
    for idx, inst in aws_instance.web2 : idx => inst
  } : {}

  nlb_attachments = var.lb_type == "network" ? {
    for idx, inst in aws_instance.web2 : idx => inst
  } : {}
}

#------------- Target Groups ----------------------------------
resource "aws_lb_target_group" "alb_tg" {
  count     = var.lb_type == "application" ? 1 : 0
  name      = "${var.user_name}-alb-tg"
  port      = var.server_port
  protocol  = "HTTP"
  vpc_id    = aws_vpc.test.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 5
    matcher             = 200
    path                = var.health_path
    protocol            = "HTTP"
    port                = var.server_port
    timeout             = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "nlb_tg" {
  count     = var.lb_type == "network" ? 1 : 0
  name      = "${var.user_name}-nlb-tg"
  port      = var.server_port
  protocol  = "TCP"
  vpc_id    = aws_vpc.test.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 10
    protocol            = "TCP"
    port                = var.server_port
    timeout             = 5
    unhealthy_threshold = 3
  }
}

#------------- Load Balancer ----------------------------------
resource "aws_lb" "lb" {
  name               = "${var.user_name}-${var.lb_type}-lb"
  internal           = false
  load_balancer_type = var.lb_type
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  security_groups    = var.lb_type == "application" ? [aws_security_group.alb_sg[0].id] : null

  tags = {
    Name = "${var.user_name}-lb"
  }
}

#------------- Security Group ----------------------------------
resource "aws_security_group" "alb_sg" {
  count       = var.lb_type == "application" ? 1 : 0
  name        = "${var.user_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id = aws_vpc.test.id

  ingress {
    description = "Allow TLS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
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
    Name = "${var.user_name}-alb-sg"
  }
}

#------------- Listeners ----------------------------------
resource "aws_lb_listener" "alb_listener" {
  count              = var.lb_type == "application" ? 1 : 0
  load_balancer_arn  = aws_lb.lb.arn
  port               = 80
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg[0].arn
  }
}

resource "aws_lb_listener" "nlb_listener" {
  count              = var.lb_type == "network" ? 1 : 0
  load_balancer_arn  = aws_lb.lb.arn
  port               = 80
  protocol           = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg[0].arn
  }
}

#------------- Target Group Attachments ----------------------------------
resource "aws_lb_target_group_attachment" "alb_to_tg" {
  for_each = local.alb_attachments

  target_group_arn = aws_lb_target_group.alb_tg[0].arn
  target_id        = each.value.id
  port             = var.server_port
}

resource "aws_lb_target_group_attachment" "nlb_to_tg" {
  for_each = local.nlb_attachments

  target_group_arn = aws_lb_target_group.nlb_tg[0].arn
  target_id        = each.value.id
  port             = var.server_port
}
