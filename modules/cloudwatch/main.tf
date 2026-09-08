################################################################################
# Module CloudWatch – Logs, Alarmes et SNS
################################################################################

# ── Topic SNS pour les alertes ───────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = { Name = "${var.name_prefix}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ── Groupe de logs ECS ────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 30

  tags = { Name = "${var.name_prefix}-ecs-logs" }
}

# ── Alarme : CPU ECS élevé ────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU ECS > 80% pendant 2 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "${var.name_prefix}-cluster"
    ServiceName = "${var.name_prefix}-service"
  }
}

# ── Alarme : Mémoire ECS élevée ───────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.name_prefix}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Mémoire ECS > 85% pendant 2 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "${var.name_prefix}-cluster"
    ServiceName = "${var.name_prefix}-service"
  }
}

# ── Alarme : Erreurs HTTP 5xx ALB ────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "Plus de 10 erreurs 5xx en 1 minute"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# ── Alarme : Santé des cibles ALB (unhealthy hosts) ──────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "Au moins une cible ALB est en mauvaise santé"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
  }
}

# ── Alarme : CPU RDS élevé ────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU RDS > 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = "${var.name_prefix}-postgres"
  }
}

# ── Alarme : Espace libre RDS faible ─────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.name_prefix}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648  # 2 Go en octets
  alarm_description   = "Espace libre RDS < 2 Go"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = "${var.name_prefix}-postgres"
  }
}

# ── Dashboard CloudWatch ──────────────────────────────────────────────────────
# ── Dashboard CloudWatch ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", "${var.name_prefix}-cluster", "ServiceName", "${var.name_prefix}-service"],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", "${var.name_prefix}-cluster", "ServiceName", "${var.name_prefix}-service"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU & Memoire"
          view   = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Requetes & Erreurs 5xx"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${var.name_prefix}-postgres"],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${var.name_prefix}-postgres"]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "RDS CPU & Connexions"
          view   = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      }
    ]
  })
}
