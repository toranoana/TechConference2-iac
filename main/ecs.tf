# ECSクラスター
resource "aws_ecs_cluster" "main" {
  name = "sample-${terraform.workspace}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT",
  ]
}

# ECS実行用ロール(Webコンソールでタスク定義作成時に自動生成されたもの)
data "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
}

# サービス検出
resource "aws_service_discovery_private_dns_namespace" "main" {
  vpc  = aws_vpc.vpc.id
  name = "sample-${terraform.workspace}"
}

resource "aws_service_discovery_service" "front" {
  name = "front-app"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "back" {
  name = "back-app"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ECSサービス front
resource "aws_ecs_service" "front" {
  cluster                 = aws_ecs_cluster.main.id
  desired_count           = 2
  enable_ecs_managed_tags = true
  launch_type             = "FARGATE"
  name                    = "sample-front"
  platform_version        = "1.4.0"
  scheduling_strategy     = "REPLICA"
  task_definition         = data.aws_ecs_task_definition.front.arn

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    container_name   = "sample-front-web"
    container_port   = 80
    target_group_arn = aws_lb_target_group.front.arn
  }

  network_configuration {
    assign_public_ip = true
    security_groups = [
      aws_security_group.app.id,
    ]
    subnets = [for n, s in aws_subnet.app : s.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.front.arn
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
    ]
  }
}

# ECSサービス back
resource "aws_ecs_service" "back" {
  cluster                 = aws_ecs_cluster.main.id
  desired_count           = 2
  enable_ecs_managed_tags = true
  launch_type             = "FARGATE"
  name                    = "sample-back"
  platform_version        = "1.4.0"
  scheduling_strategy     = "REPLICA"
  task_definition         = data.aws_ecs_task_definition.back.arn

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    container_name   = "sample-back-web"
    container_port   = 80
    target_group_arn = aws_lb_target_group.back.arn
  }

  network_configuration {
    assign_public_ip = true
    security_groups = [
      aws_security_group.app.id,
    ]
    subnets = [for n, s in aws_subnet.app : s.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.back.arn
  }
}

# ECSオートスケール設定 front
resource "aws_appautoscaling_target" "ecs_front" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.front.name}"
  min_capacity       = aws_ecs_service.front.desired_count
  max_capacity       = 6
}

resource "aws_appautoscaling_policy" "ecs_front" {
  name               = "cpu"
  service_namespace  = aws_appautoscaling_target.ecs_front.service_namespace
  scalable_dimension = aws_appautoscaling_target.ecs_front.scalable_dimension
  resource_id        = aws_appautoscaling_target.ecs_front.resource_id
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 600
    scale_out_cooldown = 600
  }
}

# ECSオートスケール設定 back
resource "aws_appautoscaling_target" "ecs_back" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.back.name}"
  min_capacity       = aws_ecs_service.back.desired_count
  max_capacity       = 6

  lifecycle {
    ignore_changes = [
      min_capacity,
      max_capacity,
    ]
  }
}

resource "aws_appautoscaling_policy" "ecs_back" {
  name               = "cpu"
  service_namespace  = aws_appautoscaling_target.ecs_back.service_namespace
  scalable_dimension = aws_appautoscaling_target.ecs_back.scalable_dimension
  resource_id        = aws_appautoscaling_target.ecs_back.resource_id
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 600
    scale_out_cooldown = 600
  }
}

# タスク定義 front
data "aws_ecs_task_definition" "front" {
  task_definition = "sample-${terraform.workspace}-front"
}

# タスク定義 back
data "aws_ecs_task_definition" "back" {
  task_definition = "sample-${terraform.workspace}-back"
}

# CloudWatchロググループ front アプリ用
resource "aws_cloudwatch_log_group" "ecs_front" {
  name = "/ecs/sample-${terraform.workspace}/sample-front"
}

# CloudWatchロググループ back アプリ用
resource "aws_cloudwatch_log_group" "ecs_back" {
  name = "/ecs/sample-${terraform.workspace}/sample-back"
}
