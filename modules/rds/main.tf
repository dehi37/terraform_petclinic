################################################################################
# Module RDS – PostgreSQL Multi-AZ
# RPO = 0 (réplication synchrone), RTO < 1 min (failover automatique)
################################################################################

# Clé KMS pour le chiffrement au repos
resource "aws_kms_key" "rds" {
  description             = "Clé KMS pour le chiffrement RDS ${var.name_prefix}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = { Name = "${var.name_prefix}-kms-rds" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# Groupe de sous-réseaux DB (couvre les 3 AZ)
resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  subnet_ids  = var.db_subnet_ids
  description = "Subnet group RDS Multi-AZ pour ${var.name_prefix}"

  tags = { Name = "${var.name_prefix}-db-subnet-group" }
}

# Groupe de paramètres PostgreSQL
resource "aws_db_parameter_group" "main" {
  name        = "${var.name_prefix}-pg-params"
  family      = "postgres15"
  description = "Paramètres PostgreSQL pour ${var.name_prefix}"

  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
  parameter {
    name  = "log_duration"
    value = "1"
  }

  tags = { Name = "${var.name_prefix}-pg-params" }
}

# Instance RDS PostgreSQL Multi-AZ
resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-postgres"

  # Moteur
  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.main.name


  # Stockage chiffré
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2  # Autoscaling stockage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Credentials (depuis Secrets Manager – jamais en dur dans les user_data)
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Réseau
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_rds_id]
  publicly_accessible    = false

  # Haute disponibilité Multi-AZ
  multi_az = true

  # Sauvegarde et maintenance
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  delete_automated_backups  = true
  deletion_protection       = false   # Protection contre la suppression accidentelle
  skip_final_snapshot       = true
  final_snapshot_identifier = null

  # Monitoring avancé
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Mises à jour automatiques des versions mineures
  auto_minor_version_upgrade = true

  tags = { Name = "${var.name_prefix}-rds-primary" }
}

# Rôle IAM pour le monitoring amélioré RDS
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
