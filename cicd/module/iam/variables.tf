#入力パラメーター
variable "name" {}       #IAMロールとIAMポリシーの名前
variable "policy" {}     #ポリシードキュメント
variable "identifier" {} #IAMロールを関連づけるAWSのサービス識別子
