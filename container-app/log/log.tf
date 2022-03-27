#CloudWatch Logs永続化バケットの定義
resource "aws_s3_bucket" "cloudwatch_logs" {
  bucket = "cloudwatch-logs-pragmatic-terraform-20220323"
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudwatch_logs" {
  rule {
    status = "Enabled"
    expiration {
      days = "180"
    }
  }
}

#Kinesis Data Firehose IAMロールのポリシードキュメントの定義
data "aws_iam_policy_document" "kinesis_data_firehose" {
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}",
      "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}/*"
    ]
  }
}

#Kinesis Data Firehose IAMロールの定義
module "kinesis_data_firehose_role" {
  source     = "../iam_role"
  name       = "kinesis-data-firehose"
  identifier = "firehose.amazonaws.com"
  policy     = data.aws_iam_policy_document.kinesis_data_firehose.json
}

#Kinesis Data Firehose配信ストリームの定義
resource "aws_kinesis_firehose_delivery_stream" "example" {
  name        = "example"
  destination = "s3"
  s3_configuration {
    role_arn   = module.kinesis_data_firehose_role.iam_role_arn
    bucket_arn = aws_s3_bucket.cloudwatch_logs.arn
    prefix     = "ecs-scheduled-tasks/example/"
  }
}

#CloudWatch Logs IAMロールのポリシードキュメントの定義
data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    effect    = "Allow"
    actions   = ["firehose:*"]
    resources = ["arn:aws:firehose:ap-northeast-1:*:*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/cloudwatch-logs"]
  }
}

#CloudWatch Logs IAMロールの定義
module "cloudwatch_logs_role" {
  source     = "../iam_role"
  name       = "cloudwatch-logs"
  identifier = "logs.ap-northeast-1.amazonaws.com"
  policy     = data.aws_iam_policy_document.cloudwatch_logs.json
}

#CloudWatch Logsサブスクリプションフィルタの定義
resource "aws_cloudwatch_log_subscription_filter" "example" {
  name            = "example"
  log_group_name  = aws_cloudwatch_log_group.for_ecs_scheduled_tasks.name #関連づけるロググループ名
  destination_arn = aws_kinesis_firehose_delivery_stream.example.arn      #送信先
  filter_pattern  = "[]"                                                  #全部送る
  role_arn        = module.cloudwatch_logs_role.iam_role_arn
}
