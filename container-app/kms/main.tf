#カスタマーマスターキーの定義
resource "aws_kms_key" "example" {
  description             = "Example Customer Master Key"
  enable_key_rotation     = true #自動ローテーション
  is_enabled              = true
  deletion_window_in_days = 30 #削除待機期間
}

#エイリアス定義
resource "aws_kms_alias" "example" {
  name          = "alias/example" #alias/というプレフィックスが必要
  target_key_id = aws_kms_key.example.key_id
}

output "kms_arn" {
  value = aws_kms_key.example.arn
}
