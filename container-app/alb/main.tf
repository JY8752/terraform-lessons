variable "vpc_id" {}
variable "subnet_id" {}
variable "alb_log_bucket" {}

module "http_sg" {
  source      = "../security_group"
  name        = "http-sg"
  vpc_id      = var.vpc_id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "../security_group"
  name        = "https-sg"
  vpc_id      = var.vpc_id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "../security_group"
  name        = "http-redirect-sg"
  vpc_id      = var.vpc_id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_alb" "example" {
  name                       = "example"
  load_balancer_type         = "application" #networkを指定するとNLB
  internal                   = false         #ALBがインターネット向けなのかVPC内部向けなのか.インターネット向けの場合はfalse
  idle_timeout               = 60
  enable_deletion_protection = true #削除保護
  #サブネット
  subnets = var.subnet_id
  #アクセスログ
  access_logs {
    bucket  = var.alb_log_bucket
    enabled = true
  }
  #sg
  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id,
  ]
}

#ALBリスナー
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.example.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "fixed-response" #固定のHTTPレスポンス応答
    fixed_response {
      content_type = "text/plain"
      message_body = "これは「HTTP」です"
      status_code  = "200"
    }
  }
}

output "alb_dns_name" {
  value = aws_alb.example.dns_name
}

output "alb_zone_id" {
  value = aws_alb.example.zone_id
}

output "alb_arn" {
  value = aws_alb.example.arn
}

output "alb" {
  value = aws_alb.example
}
