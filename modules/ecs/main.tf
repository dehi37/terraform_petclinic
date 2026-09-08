################################################################################
# Module ECS Fargate
# Cluster, Task Definition, Service Multi-AZ + Auto Scaling (CPU)
################################################################################

# ── Cluster ECS ──────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.name_prefix}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ── Task Definition ───────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "petclinic"
      image     = var.container_image
      essential = true

      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      # Variables d'environnement – JAMAIS de secrets en clair ici
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "postgres" },
        { name = "SERVER_PORT", value = tostring(var.container_port) },
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${var.db_endpoint}/${var.db_name}" }
      ]

      # Secrets injectés depuis Secrets Manager
      secrets = [
        { name = "SPRING_DATASOURCE_USERNAME", valueFrom = "${var.db_secret_arn}:username::" },
        { name = "SPRING_DATASOURCE_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }

      # Limits de ressources (sécurité)
      linuxParameters = {
        readonlyRootFilesystem = false
        initProcessEnabled     = true
      }
    }
  ])

  tags = { Name = "${var.name_prefix}-task" }
}

# ── Service ECS (Multi-AZ) ────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.ecs_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_app_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "petclinic"
    container_port   = var.container_port
  }

  # Déploiement sans interruption
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # ECS Exec pour le débogage (sans clé SSH)
  enable_execute_command = true

  health_check_grace_period_seconds = 120

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = { Name = "${var.name_prefix}-service" }
}

# ── Auto Scaling ──────────────────────────────────────────────────────────────
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scaling basé sur le CPU
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_scaling_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Scaling basé sur la mémoire
resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.name_prefix}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 80
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
