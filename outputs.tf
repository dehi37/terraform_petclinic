output "alb_dns_name" {
  description = "URL publique de l'application (ALB)"
  value       = "https://${module.alb.alb_dns_name}"
}

output "ecr_repository_url" {
  description = "URL du registre ECR pour pousser l'image Docker"
  value       = module.ecr.repository_url
}

output "rds_endpoint" {
  description = "Endpoint de la base de données RDS (accès interne uniquement)"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS"
  value       = module.ecs.cluster_name
}

output "vpc_id" {
  description = "ID du VPC"
  value       = module.vpc.vpc_id
}

output "db_secret_arn" {
  description = "ARN du secret Secrets Manager contenant les credentials RDS"
  value       = module.secrets.db_secret_arn
  sensitive   = true
}

output "deploy_instructions" {
  description = "Instructions pour pousser l'image Docker et déployer"
  value = <<-EOT
    ====== Instructions de déploiement ======

    1. Authentifier Docker auprès d'ECR :
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.repository_url}

    2. Builder et pousser l'image :
       docker build -t ${var.project_name} .
       docker tag ${var.project_name}:latest ${module.ecr.repository_url}:latest
       docker push ${module.ecr.repository_url}:latest

    3. Forcer le redéploiement ECS :
       aws ecs update-service --cluster ${module.ecs.cluster_name} --service ${module.ecs.service_name} --force-new-deployment

    4. Application accessible sur :
       https://${module.alb.alb_dns_name}

    5. Nettoyage sur le terraform avec terraform:
       terraform destroy -auto-approve
       Remove-Item terraform.tfstate* -ErrorAction SilentlyContinue
       Remove-Item .terraform -Recurse -Force -ErrorAction SilentlyContinue
       Remove-Item .terraform.lock.hcl -ErrorAction SilentlyContinue
  EOT
}
