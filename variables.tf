variable "aws_region" {
  description = "Région AWS cible"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Nom du projet (utilisé pour nommer les ressources)"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "binome_name" {
  description = "Identifiant du binôme pour l'isolation des ressources"
  type        = string
  default     = "binome-tp3"
}

# ── Réseau ──────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zones de disponibilité à utiliser"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs des sous-réseaux publics (un par AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs des sous-réseaux privés applicatifs (un par AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDRs des sous-réseaux privés base de données (un par AZ)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

# ── ALB / TLS ────────────────────────────────────────────────────────────────
variable "domain_name" {
  description = "Nom de domaine pour le certificat ACM (laisser vide pour générer un certificat auto-signé)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN du certificat ACM existant (si vide, un certificat sera créé ou le HTTP sera utilisé)"
  type        = string
  default     = ""
}

# ── ECS ─────────────────────────────────────────────────────────────────────
variable "container_image" {
  description = "Image Docker de l'application (ex: <account>.dkr.ecr.us-east-1.amazonaws.com/petclinic:latest)"
  type        = string
  default     = ""  # sera remplacé par l'image ECR après push
}

variable "container_port" {
  description = "Port exposé par le conteneur Spring Boot"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "CPU alloué à la tâche Fargate (unités vCPU x 1024)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Mémoire allouée à la tâche Fargate (Mo)"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Nombre de tâches ECS souhaitées au démarrage"
  type        = number
  default     = 3
  #default     = 0  # ◄── MODIFIE ICI : Passe de 3 à 0 pour éteindre les conteneurs
}

variable "ecs_min_count" {
  description = "Nombre minimum de tâches ECS (auto-scaling)"
  type        = number
  default     = 2
}

variable "ecs_max_count" {
  description = "Nombre maximum de tâches ECS (auto-scaling)"
  type        = number
  default     = 6
}

variable "cpu_scaling_target" {
  description = "Seuil CPU (%) pour déclencher l'auto-scaling"
  type        = number
  default     = 70
}

# ── RDS ─────────────────────────────────────────────────────────────────────
variable "db_name" {
  description = "Nom de la base de données PostgreSQL"
  type        = string
  default     = "petclinic"
}

variable "db_username" {
  description = "Nom de l utilisateur principal RDS"
  type        = string
  default     = "petclinic_admin"
}

variable "db_instance_class" {
  description = "Type d instance RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Stockage alloue à RDS (Go)"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Version PostgreSQL"
  type        = string
  default     = "15.17"
}

# ── Monitoring ───────────────────────────────────────────────────────────────
variable "alarm_email" {
  description = "Adresse e-mail pour les alertes CloudWatch"
  type        = string
  default     = "mpididehi@gmail.com"
}

# ── Budget ───────────────────────────────────────────────────────────────────
variable "monthly_budget_usd" {
  description = "Plafond mensuel AWS Budgets (USD)"
  type        = number
  default     = 50
}

variable "budget_alert_threshold" {
  description = "Seuil d alerte budget en pourcentage"
  type        = number
  default     = 80
}
