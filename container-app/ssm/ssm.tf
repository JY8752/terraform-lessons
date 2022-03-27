resource "aws_ssm_parameter" "db_username" {
  name        = "/db/username"
  value       = "root"
  type        = "String"
  description = "データベースのユーザー名"
}

resource "aws_ssm_parameter" "db_raw_password" {
  name        = "/db/raw_password"
  value       = "uninitialized" #秘匿情報は後からCLIで値を入れるためダミー値を入れる
  type        = "SecureString"
  description = "データベースのパスワード"
  lifecycle {
    ignore_changes = [value]
  }
}
