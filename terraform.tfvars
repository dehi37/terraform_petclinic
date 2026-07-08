# Copier ce fichier en terraform.tfvars et adapter les valeurs

aws_region   = "us-east-1"
project_name = "petclinic-isi"
environment  = "prod"
binome_name = "Binome$Dehi_Atikh"   # Remplacer par vos noms

# Réseau
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
db_subnet_cidrs      = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

# TLS – Laisser vide si pas de domaine (le listener HTTPS sera désactivé)
domain_name     = ""


# ECS Fargate
container_port    = 8080
task_cpu          = 512
task_memory       = 1024
ecs_desired_count = 3
ecs_min_count     = 2
ecs_max_count     = 6
cpu_scaling_target = 70

# RDS PostgreSQL
db_name              = "petclinic"
db_username          = "petclinic_admin"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_engine_version    = "15.17"

# Alertes
# personnalise a votre convenance
alarm_email = "mpididehi@mail.com"

# Budget (USD)
monthly_budget_usd     = 50
budget_alert_threshold = 80
