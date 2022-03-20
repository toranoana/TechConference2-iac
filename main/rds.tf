# RDSクラスター
resource "aws_rds_cluster" "main" {
  cluster_identifier              = "sample-${terraform.workspace}"
  engine                          = data.aws_rds_engine_version.aurora_latest.engine
  engine_version                  = data.aws_rds_engine_version.aurora_latest.id
  database_name                   = "sample_${terraform.workspace}"
  master_username                 = "admin"
  master_password                 = "password" # 初期パスワード(構築後はWebコンソールから要変更)
  backup_retention_period         = 1
  preferred_backup_window         = "16:30-17:00"
  deletion_protection             = false
  skip_final_snapshot             = true
  copy_tags_to_snapshot           = true
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  db_subnet_group_name            = aws_db_subnet_group.rds_subnets.name

  availability_zones = [
    data.aws_availability_zones.az.names[0],
    data.aws_availability_zones.az.names[1],
  ]

  vpc_security_group_ids = [
    aws_security_group.db.id,
  ]

  enabled_cloudwatch_logs_exports = [
    "audit",
    "error",
    "slowquery",
  ]

  lifecycle {
    ignore_changes = [
      # 自動アップデートさせるので除外
      engine_version,
      # Webコンソールから変更かけるので除外
      master_password,
      # Webコンソールから変更かけるので除外
      preferred_backup_window,
      # 何故か差分が出てしまうため除外
      availability_zones,
    ]
  }
}

# RDSインスタンス
resource "aws_rds_cluster_instance" "main_instances" {
  count = 2

  identifier              = "sample-${terraform.workspace}-instance-${count.index}"
  cluster_identifier      = aws_rds_cluster.main.id
  engine                  = aws_rds_cluster.main.engine
  engine_version          = aws_rds_cluster.main.engine_version
  instance_class          = local.is_prod ? "db.t3.medium" : "db.t3.small"
  db_subnet_group_name    = aws_db_subnet_group.rds_subnets.name
  db_parameter_group_name = "default.aurora-mysql5.7"
  promotion_tier          = 1
  monitoring_role_arn     = data.aws_iam_role.rds_monitoring.arn
  monitoring_interval     = 60

  lifecycle {
    ignore_changes = [
      identifier,
    ]
  }
}

# レプリカオートスケール設定
resource "aws_appautoscaling_target" "main_instance_replicas" {
  service_namespace  = "rds"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  resource_id        = "cluster:${aws_rds_cluster.main.id}"
  min_capacity       = 2
  max_capacity       = 10
}

# オートスケールポリシー
resource "aws_appautoscaling_policy" "main_instance_replicas" {
  name               = "sample-${terraform.workspace}-auto-scale-policy"
  service_namespace  = aws_appautoscaling_target.main_instance_replicas.service_namespace
  scalable_dimension = aws_appautoscaling_target.main_instance_replicas.scalable_dimension
  resource_id        = aws_appautoscaling_target.main_instance_replicas.resource_id
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }

    target_value       = 45
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# AuroraDBエンジンの最新エンジンバージョン取得
data "aws_rds_engine_version" "aurora_latest" {
  engine                 = "aurora-mysql"
  parameter_group_family = "aurora-mysql5.7"
}

# サブネットグループ
resource "aws_db_subnet_group" "rds_subnets" {
  name        = "sample-${terraform.workspace}-rds"
  description = "rds subnets"
  subnet_ids  = [for n, s in aws_subnet.db : s.id]
}

# RDSモニタリング用ロール(Webコンソールから作成時に自動生成されたもの)
data "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"
}

# パラメーターグループ
resource "aws_rds_cluster_parameter_group" "main" {
  name        = "sample-${terraform.workspace}-params"
  description = "rds params"
  family      = "aurora-mysql5.7"

  parameter {
    apply_method = "immediate"
    name         = "character_set_client"
    value        = "utf8mb4"
  }
  parameter {
    apply_method = "immediate"
    name         = "character_set_connection"
    value        = "utf8mb4"
  }
  parameter {
    apply_method = "immediate"
    name         = "character_set_database"
    value        = "utf8mb4"
  }
  parameter {
    apply_method = "immediate"
    name         = "character_set_results"
    value        = "utf8mb4"
  }
  parameter {
    apply_method = "immediate"
    name         = "character_set_server"
    value        = "utf8mb4"
  }
  parameter {
    apply_method = "immediate"
    name         = "require_secure_transport"
    value        = "ON"
  }
  parameter {
    apply_method = "immediate"
    name         = "time_zone"
    value        = "Asia/Tokyo"
  }
}
