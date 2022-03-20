# ロードバランサ
resource "aws_lb" "alb" {
  name               = "sample-${terraform.workspace}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = true

  security_groups = [
    aws_security_group.public.id,
  ]
}

# ロードバランサ http(httpsへのリダイレクトを行う)
resource "aws_lb_listener" "alb_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      host        = "#{host}"
      path        = "/#{path}"
      port        = 443
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

# ロードバランサ https
resource "aws_lb_listener" "alb_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front.arn
  }
}

resource "aws_lb_listener_rule" "alb_https_api" {
  listener_arn = aws_lb_listener.alb_https.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back.arn
  }

  condition {
    path_pattern {
      values = [
        "/api/*",
      ]
    }
  }
}

# 現在有効なTLS証明書
# 証明書の入れ替えは要手動対応
data "aws_acm_certificate" "main" {
  domain   = local.cert_domain
  statuses = ["ISSUED"]
}
