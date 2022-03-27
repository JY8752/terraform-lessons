module "vpc" {
  source = "../vpc"
}

module "kms" {
  source = "../kms"
}

#DBパラメーターグループの定義
resource "aws_db_parameter_group" "example" {
  name   = "example"
  family = "mysql5.7"
  parameter {
    name  = "caracter_set_database"
    value = "utf8mb4"
  }
  parameter {
    name  = "caracter_set_server"
    value = "utf8mb4"
  }
}

#DBオプショングループの定義
resource "aws_db_option_group" "example" {
  name                 = "example"
  engine_name          = "mysql"
  major_engine_version = "5.7"
  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}

#DBサブネットグループの定義
resource "aws_db_subnet_group" "example" {
  name       = "example"
  subnet_ids = module.vpc.private_subnet_id
}

#DBインスタンスの定義
resource "aws_db_instance" "example" {
  identifier                 = "example"
  engine                     = "mysql"
  engine_version             = "5.7.25"
  instance_class             = "db.t3.small"
  allocated_storage          = 20
  max_allocated_storage      = 100
  storage_type               = "gp2"
  storage_encrypted          = true
  kms_key_id                 = module.kms.kms_arn #ディスク暗号化が有効
  username                   = "admin"
  password                   = "VeryStrongPassword!" #あとで変える!!
  multi_az                   = true
  publicly_accessible        = false
  backup_window              = "09:10-09:40"         #バックアップの時間.UTC時間
  backup_retention_period    = 30                    #バックアップ期間
  maintenance_window         = "mon:10:10-mon:10:40" #メンテナンスの時間.UTC時間
  auto_minor_version_upgrade = false                 #自動マイナーバージョンアップの無効化
  deletion_protection        = true                  #削除保護
  skip_final_snapshot        = false
  port                       = 3306
  apply_immediately          = false #即時反映の無効化
  vpc_security_group_ids     = [module.mysql_sg.security_group_id]
  parameter_group_name       = aws_db_parameter_group.example.name
  option_group_name          = aws_db_option_group.example.name
  db_subnet_group_name       = aws_db_subnet_group.example.name
  lifecycle {
    ignore_changes = [password] #あとで変更するため変更を無視する
  }
}

module "mysql_sg" {
  source      = "../security_group"
  name        = "mysql-sg"
  vpc_id      = module.vpc.aws_vpc_id
  port        = 3306
  cidr_blocks = [module.vpc.aws_vpc_cidr_block]
}

#DBの削除
#削除保護とスナップショットのスキップを有効にしてdestroy
