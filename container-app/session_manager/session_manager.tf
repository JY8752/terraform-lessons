module "vpc" {
  source = "../vpc"
}

#オペレーションサーバー用ポリシードキュメントの定義
data "aws_iam_policy_document" "ec2_for_ssm" {
  source_policy_documents = [data.aws_iam_policy.ec2_for_ssm.policy]
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "s3:PutObject",
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "kms:Decrypt"
    ]
  }
}

data "aws_iam_policy" "ec2_for_ssm" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#オペレーションサーバー用IAMロールの定義
module "ec2_for_ssm_role" {
  source     = "../iam_role"
  name       = "ec2-for-ssm"
  identifier = "ec2.amazonaws.com"
  policy     = data.aws_iam_policy_document.ec2_for_ssm.json
}

#インスタンスプロファイルの定義
resource "aws_iam_instance_profile" "ec2_for_ssm" {
  name = "ec2-for-ssm"
  role = module.ec2_for_ssm_role.iam_role_name
}

#オペレーションサーバー用EC2インスタンスの定義
resource "aws_instance" "example_for_operation" {
  ami                  = "ami-0c3fd0f5d33134a76"
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_for_ssm.name
  subnet_id            = module.vpc.private_subnet_id[0]
  user_data            = file("./session_manager/user_data.sh")
}

output "operation_instance_id" {
  value = aws_instance.example_for_operation.id
}

#オペレーションログを保存するS3バケットの定義
resource "aws_s3_bucket" "operation" {
  bucket = "operation-pragmatic-terraform-lessones"
}

resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = aws_s3_bucket.operation.bucket
  rule {
    id     = "config"
    status = "Enabled"
    expiration {
      days = "180"
    }
  }
}

#オペレーションログを保存するCloudWatch Logsの定義
resource "aws_cloudwatch_log_group" "operation" {
  name              = "/operation"
  retention_in_days = 180
}

#SessionManager用SSM Documentの定義
resource "aws_ssm_document" "session_manager_run_shell" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"
  content         = <<EOF
  {
      "schemaVersion": "1.0",
      "description": "Document to hold regional settings for SessionManager",
      "sessionType": "Standard_Stream",
      "inputs": {
          "s3BucketName": "${aws_s3_bucket.operation.id}",
          "cloudWatchLogGroupName": "${aws_cloudwatch_log_group.operation.name}"
      }
  }
  EOF
}
