#EC2のリージョン一覧を取得するIAMロールの作成
# module "describe_regions_for_ec2" {
#   source     = "./iam_role"
#   name       = "describe_regions_for_ec2"
#   identifier = "ec2.amazonaws.com"
#   policy     = data.aws_iam_policy_document.allow_describe_regions.json
# }

# module "s3module" {
#   source = "./s3"
# }

# module "vpc" {
#   source = "./vpc"
# }

# module "alb" {
#   source         = "./alb"
#   vpc_id         = module.vpc.aws_vpc_id
#   subnet_id      = module.vpc.public_subnet_id
#   alb_log_bucket = module.s3module.alb_log_bucket_id
# }

# module "route53" {
#   source   = "./route53"
#   dns_name = module.alb.alb_dns_name
#   zone_id  = module.alb.alb_zone_id
#   alb_arn  = module.alb.alb_arn
#   vpc_id   = module.vpc.aws_vpc_id
#   alb      = module.alb.alb
# }

# module "ecs" {
#   source = "./ecs"
# }

# module "batch" {
#   source = "./batch"
# }

# module "kms" {
#   source = "./kms"
# }

# module "rds" {
#   source = "./rds"
# }

# module "elastic" {
#   source = "./elastichache"
# }

# module "code_pipeline" {
#   source = "./code_pipeline"
# }

# module "ssm" {
#   source = "./session_manager"
# }

terraform {
  #バージョンの固定
  required_version = "1.1.7"
}

provider "aws" {
  #バージョンの固定
  version = "4.5.0"
}

#AWSアカウントIDの取得
data "aws_caller_identity" "name" {}
output "accout_id" {
  value = data.aws_caller_identity.name.account_id
}

#リージョンの取得
data "aws_region" "name" {}
output "region_name" {
  value = data.aws_region.name.name
}

#アベイラビリティーゾーンの取得
data "aws_availability_zones" "name" {
  state = "available"
}
output "availability_zones" {
  value = data.aws_availability_zones.name.names
}

#パスワードのランダム生成
provider "random" {}
resource "random_string" "password" {
  length  = 32
  special = false
}
