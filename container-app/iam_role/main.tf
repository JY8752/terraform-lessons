#IAMモジュール

#入力パラメーター
variable "name" {}       #IAMロールとIAMポリシーの名前
variable "policy" {}     #ポリシードキュメント
variable "identifier" {} #IAMロールを関連づけるAWSのサービス識別子

#IAMロールの定義
resource "aws_iam_role" "default" {
  name               = var.name                                      #ロール名
  assume_role_policy = data.aws_iam_policy_document.assume_role.json #信頼ポリシー
}

#ポリシードキュメントの定義
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [var.identifier] #どのAWSサービスに関連づけられるか
    }
  }
}

#IAMポリシー
resource "aws_iam_policy" "default" {
  name   = var.name   #ポリシー名
  policy = var.policy #ポリシードキュメント
}

#IAMロールにIAMポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}

output "iam_role_arn" {
  value = aws_iam_role.default.arn
}

output "iam_role_name" {
  value = aws_iam_role.default.name
}
