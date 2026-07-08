################################################################################
# TP3 – Spring PetClinic sur AWS
# Architecture : ECS Fargate Multi-AZ + RDS PostgreSQL Multi-AZ + ALB HTTPS
# Binôme : voir variable binome_name dans terraform.tfvars
################################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── 1. VPC & Réseau ──────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

# ── 2. Security Groups (SG ALB → SG APP → SG RDS) ───────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  container_port = var.container_port
}

# ── 3. ECR – Registre d'images Docker ────────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"

  name_prefix  = local.name_prefix
  project_name = var.project_name
}

# ── 4. IAM – Rôles et politiques (moindre privilège) ─────────────────────────
module "iam" {
  source = "./modules/iam"

  name_prefix          = local.name_prefix
  aws_region           = var.aws_region
  db_secret_arn        = module.secrets.db_secret_arn
  ecr_repository_arn   = module.ecr.repository_arn
  log_group_arn        = module.cloudwatch.ecs_log_group_arn
}

# ── 5. Secrets Manager – Mot de passe RDS ────────────────────────────────────
module "secrets" {
  source = "./modules/secrets"

  name_prefix  = local.name_prefix
  db_name      = var.db_name
  db_username  = var.db_username
}

# ── 6. RDS PostgreSQL Multi-AZ ───────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  name_prefix          = local.name_prefix
  db_subnet_ids        = module.vpc.db_subnet_ids
  sg_rds_id            = module.security_groups.sg_rds_id
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = module.secrets.db_password
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine_version    = var.db_engine_version
}

# ── 7. CloudWatch – Logs & Alarmes ───────────────────────────────────────────
module "cloudwatch" {
  source = "./modules/cloudwatch"

  name_prefix    = local.name_prefix
  aws_region     = var.aws_region
  alarm_email    = var.alarm_email
  alb_arn_suffix = module.alb.alb_arn_suffix
  tg_arn_suffix  = module.alb.tg_arn_suffix
}

# ── 8. ALB – Application Load Balancer HTTPS ─────────────────────────────────
module "alb" {
  source = "./modules/alb"

  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  sg_alb_id        = module.security_groups.sg_alb_id
  container_port   = var.container_port
  certificate_arn = module.iam.certificate_arn
  #certificate_arn  = var.certificate_arn
  domain_name      = var.domain_name
}

# ── 9. ECS Fargate – Service applicatif + Auto Scaling ───────────────────────
module "ecs" {
  source = "./modules/ecs"

  name_prefix             = local.name_prefix
  aws_region              = var.aws_region
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  sg_app_id               = module.security_groups.sg_app_id
  alb_target_group_arn    = module.alb.target_group_arn
  container_image         = var.container_image != "" ? var.container_image : "${module.ecr.repository_url}:latest"
  container_port          = var.container_port
  task_cpu                = var.task_cpu
  task_memory             = var.task_memory
  ecs_desired_count       = var.ecs_desired_count
  ecs_min_count           = var.ecs_min_count
  ecs_max_count           = var.ecs_max_count
  cpu_scaling_target      = var.cpu_scaling_target
  execution_role_arn      = module.iam.ecs_execution_role_arn
  task_role_arn           = module.iam.ecs_task_role_arn
  log_group_name          = module.cloudwatch.ecs_log_group_name
  db_secret_arn           = module.secrets.db_secret_arn
  db_endpoint             = module.rds.db_endpoint
  db_name                 = var.db_name
}

# ── 10. AWS Budgets ───────────────────────────────────────────────────────────
module "budgets" {
  source = "./modules/budgets"

  name_prefix            = local.name_prefix
  binome_name            = var.binome_name
  monthly_budget_usd     = var.monthly_budget_usd
  budget_alert_threshold = var.budget_alert_threshold
  alarm_email            = var.alarm_email
}
