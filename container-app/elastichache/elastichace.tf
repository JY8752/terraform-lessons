module "vpc" {
  source = "../vpc"
}

#パラメーターグループの定義
resource "aws_elasticache_parameter_group" "example" {
  name   = "example"
  family = "redis5.0"
  parameter {
    name  = "cluster-enabled"
    value = "no"
  }
}

#サブネットグループの定義
resource "aws_elasticache_subnet_group" "example" {
  name       = "example"
  subnet_ids = module.vpc.private_subnet_id
}

#レプリケーショングループの定義
resource "aws_elasticache_replication_group" "example" {
  replication_group_id       = "example"
  description                = "Cluster Disabled"
  engine                     = "redis"
  engine_version             = "5.0.4"
  num_cache_clusters         = 3
  node_type                  = "cache.m3.medium"
  snapshot_window            = "09:10-10:10"
  snapshot_retention_limit   = 7 #保持期間
  maintenance_window         = "mon:10:40-mon:11:40"
  automatic_failover_enabled = true #自動フェイルオーバーの有効
  port                       = 6379
  apply_immediately          = false #設定の即時反映を無効化
  security_group_ids         = [module.redis_sg.security_group_id]
  parameter_group_name       = aws_elasticache_parameter_group.example.name
  subnet_group_name          = aws_elasticache_subnet_group.example.name
}

module "redis_sg" {
  source      = "../security_group"
  name        = "redis-sg"
  port        = 6379
  vpc_id      = module.vpc.aws_vpc_id
  cidr_blocks = [module.vpc.aws_vpc_cidr_block]
}

#スローapply問題
#RDSやElasichaceのapplyには10分-30分以上かかることも。低スペックなインスタンスタイプでは上振れしやすい。
