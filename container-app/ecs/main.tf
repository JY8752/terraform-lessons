module "s3module" {
  source = "../s3"
}

module "vpc" {
  source = "../vpc"
}

module "alb" {
  source         = "../alb"
  vpc_id         = module.vpc.aws_vpc_id
  subnet_id      = module.vpc.public_subnet_id
  alb_log_bucket = module.s3module.alb_log_bucket_id
}

module "route53" {
  source   = "../route53"
  dns_name = module.alb.alb_dns_name
  zone_id  = module.alb.alb_zone_id
  alb_arn  = module.alb.alb_arn
  vpc_id   = module.vpc.aws_vpc_id
  alb      = module.alb.alb
}

#ECSクラスタの定義
resource "aws_ecs_cluster" "example" {
  name = "example"
}

#タスク定義
resource "aws_ecs_task_definition" "example" {
  family                   = "example" #タスク定義名のプレフィックス
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./ecs/container_definitions.json")
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
}

#サービス定義
resource "aws_ecs_service" "example" {
  name                              = "example"
  cluster                           = aws_ecs_cluster.example.arn
  task_definition                   = aws_ecs_task_definition.example.arn
  desired_count                     = 2 #維持するタスク数
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"
  health_check_grace_period_seconds = 60 #起動に時間がかかるとヘルスチェック通らなくなるので0以上に
  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]
    subnets          = module.vpc.private_subnet_id
  }
  load_balancer {
    target_group_arn = module.route53.aws_alb_target_group_arn
    container_name   = "example"
    container_port   = 80
  }
  lifecycle {
    ignore_changes = [task_definition] #リソースの初回作成時を除き変更を無視する
  }
}

module "nginx_sg" {
  source      = "../security_group"
  name        = "nginx_sg"
  vpc_id      = module.vpc.aws_vpc_id
  port        = 80
  cidr_blocks = [module.vpc.aws_vpc_cidr_block]
}

#CloudWatch Logsの定義
resource "aws_cloudwatch_log_group" "for_ecs" {
  name              = "/ecs/example"
  retention_in_days = 180 #ログ保有期間
}

#AmazonECSTaskExecutionRolePolicyの参照
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#ECSタスク実行IAMロールのポリシードキュメントの定義
data "aws_iam_policy_document" "ecs_task_execution" {
  source_policy_documents = [data.aws_iam_policy.ecs_task_execution_role_policy.policy] #既存ポリシーの継承 
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

#ECSタスク実行IAMロールの定義
module "ecs_task_execution_role" {
  source     = "../iam_role"
  name       = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com"
  policy     = data.aws_iam_policy_document.ecs_task_execution.json
}

output "cluster_name" {
  value = aws_ecs_cluster.example.name
}

output "service_name" {
  value = aws_ecs_service.example.name
}
