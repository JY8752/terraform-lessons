#1.プライベートバケット
resource "aws_s3_bucket" "private" {
  bucket = "private-pragmatic-terraform-jy" #バケット名 
}

#オブジェクトを変更・削除しても以前のバージョンへ復元できる。理由がなければ有効で
resource "aws_s3_bucket_versioning" "default" {
  bucket = aws_s3_bucket.private.id
  versioning_configuration {
    status = "Enabled"
  }
}

#暗号化。特にデメリットはない
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.private.id
  rule {
    apply_server_side_encryption_by_default {
      # kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm = "AES256"
    }
  }
}

#ブロックパブリックアクセスの設定.予期しないオブジェクトの公開を抑止できる
#特に理由がなければ全て有効でok
resource "aws_s3_bucket_public_access_block" "private" {
  bucket                  = aws_s3_bucket.private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#2.パブリックバケット
resource "aws_s3_bucket" "public" {
  bucket = "public-pragmatic-terraform-jy"
}

#アクセス権.S3バケットを作成したAWSアカウントしかアクセスできないため公開
resource "aws_s3_bucket_acl" "default" {
  bucket = aws_s3_bucket.public.id
  acl    = "public-read"
}

#CORS
resource "aws_s3_bucket_cors_configuration" "default" {
  bucket = aws_s3_bucket.public.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://s3-website-test.hashicorp.com"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

#3.ログバケット
resource "aws_s3_bucket" "alb_log" {
  bucket = "alb-log-pragmatic-terraform-jy"
}

resource "aws_s3_bucket_lifecycle_configuration" "default" {
  bucket = aws_s3_bucket.alb_log.id
  rule {
    id     = "alb access log"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 180 #180日経過でログを削除
    }
  }
}

#バケットポリシー
resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

#ポリシードキュメント
data "aws_iam_policy_document" "alb_log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]
    principals {
      type        = "AWS"
      identifiers = ["582318560864"] #リージョンごとに決まっている
    }
  }
}

#バケット削除
resource "aws_s3_bucket" "force_destroy" {
  bucket        = "force-destroy-pragmatic-terraform-jy"
  force_destroy = true #バケットがから出ないと削除できないが、強制削除
}

output "alb_log_bucket_id" {
  value = aws_s3_bucket.alb_log.id
}
