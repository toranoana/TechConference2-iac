resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "sample-${terraform.workspace}"
  description                = "sample-${terraform.workspace}-redis"
  engine_version             = "6.x"
  node_type                  = local.is_prod ? "cache.m3.medium" : "cache.t3.micro"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  snapshot_retention_limit   = 1
  multi_az_enabled           = true
  parameter_group_name       = "default.redis6.x"
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = "initial_password" # 初期認証トークン(構築後はWebコンソールから要変更)

  security_group_ids = [
    aws_security_group.db.id,
  ]

  lifecycle {
    ignore_changes = [
      auth_token,
    ]
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "sample-${terraform.workspace}-redis"
  subnet_ids = [for n, s in aws_subnet.db : s.id]
}
