variable "dns_name" {}
variable "zone_id" {}
variable "alb_arn" {}
variable "vpc_id" {}
variable "alb" {}

#ホストゾーンの参照
data "aws_route53_zone" "example" {
  name = "example.com"
}

#ホストゾーンの作成
resource "aws_route53_zone" "test_example" {
  name = "test.example.com"
}

#ALBのDNSレコードの定義
resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.example.zone_id
  name    = data.aws_route53_zone.example.name
  type    = "A" #ALIASレコード
  alias {
    name                   = var.dns_name
    zone_id                = var.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.example.name
}

#SSL証明書の定義
resource "aws_acm_certificate" "example" {
  domain_name               = aws_route53_record.example.name
  subject_alternative_names = []    #ドメイン名の追加
  validation_method         = "DNS" #DNS検証 or Eメール検証 SSL証明書を自動更新したい場合はDNS
  lifecycle {
    create_before_destroy = true #リソースを作成してからリソースを削除する
  }
}

#SSL証明書の検証用レコードの定義
resource "aws_route53_record" "example_certificate" {
  #   name    = aws_acm_certificate.example.domain_validation_options[0].resource_record_name
  #   type    = aws_acm_certificate.example.domain_validation_options[0].resource_record_type
  #   records = [aws_acm_certificate.example.domain_validation_options[0].resource_record_value]

  #AWSプロバイダー3.0.0以降からlistではなくsetで返るようになったのでインデックスからの取得ができなくなった
  #そのため下記のようにdomain_nameがkeyになるようにmapする
  for_each = {
    for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.example.id
  ttl     = 60
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
}

#検証の待機
resource "aws_acm_certificate_validation" "example" {
  certificate_arn = aws_acm_certificate.example.arn
  #   validation_record_fqdns = [aws_route53_record.example_certificate.fqdn]
  validation_record_fqdns = [for record in aws_route53_record.example_certificate : record.fqdn]
}

#HTTPSリスナーの定義
resource "aws_alb_listener" "https" {
  load_balancer_arn = var.alb_arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.example.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "これは「HTTPS」です"
      status_code  = "200"
    }
  }
}

#HTTP -> HTTPSのリダイレクト設定
resource "aws_alb_listener" "redirect_http_to_https" {
  load_balancer_arn = var.alb_arn
  port              = "8080"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#ターゲットグループの定義
resource "aws_alb_target_group" "example" {
  name                 = "example"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300 #ターゲットの登録を解除する前にALBが待機する時間
  health_check {
    path                = "/"
    healthy_threshold   = 5              #正常判定を行うまでのヘルスチェック実行回数
    unhealthy_threshold = 2              #異常判定を行うまでのヘルスチェック実行回数
    timeout             = 5              #ヘルスチェックのタイムアウト時間（秒）
    interval            = 30             #ヘルスチェックの実行間隔(秒)
    matcher             = 200            #正常判定を行うために使用するHTTPステータスコード
    port                = "traffic-port" #ヘルスチェックで使用するポート
    protocol            = "HTTP"         #ヘルスチェックで使用するプロトコル
  }
  depends_on = [
    # aws_alb.example
    var.alb
  ]
}

#リスナールールの定義
resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_alb_listener.https.arn
  priority     = 100 #優先順位
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.example.arn
  }
  condition {
    # field  = "path-pattern"
    # values = ["/*"] #全てのパス
    path_pattern {
      values = ["/*"] #全てのパス
    }
  }
}

output "aws_alb_target_group_arn" {
  value = aws_alb_target_group.example.arn
}
