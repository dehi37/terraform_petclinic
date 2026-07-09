# TP3 – Spring PetClinic sur AWS · Infrastructure Terraform

## Architecture déployée

```
Internet → ALB (HTTPS 443) → ECS Fargate (privé, 3 AZ) → RDS PostgreSQL Multi-AZ (privé)
```

| Composant | Service AWS | Pilier Well-Architected |
|-----------|------------|------------------------|
| Réseau | VPC + Subnets + NAT GW | Sécurité |
| Entrée TLS | ALB + ACM | Fiabilité / Sécurité |
| Calcul | ECS Fargate | Performance / Fiabilité |
| Scalabilité | Application Auto Scaling | Performance |
| Base de données | RDS PostgreSQL Multi-AZ | Fiabilité |
| Secrets | AWS Secrets Manager | Sécurité |
| IAM | Rôles moindre privilège | Sécurité |
| Conteneurs | ECR | Excellence opérationnelle |
| Monitoring | CloudWatch + SNS | Excellence opérationnelle |
| Coûts | AWS Budgets | Optimisation des coûts |

## Pré-requis

- Terraform >= 1.5.0
- AWS CLI configuré (`aws configure`)
- Docker installé
- Accès au compte AWS pédagogique

## Déploiement

```bash
# 1. Cloner le dépôt et aller dans le dossier terraform
cd terraform/

# 2. Copier et adapter la configuration
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec vos valeurs (binome_name, alarm_email, etc.)

# 3. Initialiser Terraform
terraform init

# 4. Vérifier les syntaxe du code
terraform validate

# 5. Vérifier le plan
terraform plan

# 6. Déployer (environ 15-20 minutes)
terraform apply

# 7. Récupérer l'URL de l'application
terraform output alb_dns_name

# 8. Se connecter au registre privé AWS ECR sur le cmd avec cette commande : 
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# 9. Construire l'image Docker localement : Toujours à l'intérieur du dossier spring-petclinic (là où se trouve le Dockerfile fourni par le projet), lancez la création de l'image Docker : 
./mvnw spring-boot:build-image

# 10. Étiqueter (Tag) l'image pour AWS ECR : 
docker tag spring-petclinic:4.0.0-SNAPSHOT $ECR_URL:latest

# 11. Push l'image sur AWS ECR : 
docker push $ECR_URL:latest

# 12. Sur AWS CLI forcer le redeployment ECS : 
aws ecs update-service --cluster petclinic-isi-prod-cluster --service petclinic-isi-prod-service --force-new-deployment

# 13. Attendre pendant 2 à 3 minutes, ensuite nous allons récupérer l’URL de l’application : 
terraform output alb_dns_name


# 14. Mettre à jour l'image dans la variable et re-appliquer
# Éditer terraform.tfvars : container_image = "$ECR_URL:latest"
terraform apply

# 15. Nettoyage (OBLIGATOIRE en fin de TP)

# a. suppressions de l'infrastructure deployée sur AWS
terraform destroy -auto-approve

# b. supprimer les logs sur AWS CLI :

aws logs delete-log-group --log-group-name /aws/vpc/petclinic-isi-prod/flow-logs
aws logs delete-log-group --log-group-name /aws/ecs/containerinsights/petclinic-isi-prod-cluster/performance
aws logs delete-log-group --log-group-name /aws/ecs/containerinsights/petclinic-prod-cluster/performance
aws logs delete-log-group --log-group-name RDSOSMetrics

# c. Supprimer les fichiers d'état locaux
Write-Host "=== Suppression du state local ==="

Remove-Item terraform.tfstate* -ErrorAction SilentlyContinue
Remove-Item .terraform -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .terraform.lock.hcl -ErrorAction SilentlyContinue



```

## Structure des modules

```
terraform/
├── main.tf                    # Orchestration des modules
├── variables.tf               # Variables globales
├── outputs.tf                 # Sorties (URL, ARN, etc.)
├── versions.tf                # Versions provider
├── terraform.tfvars.example   # Template de configuration
└── modules/
    ├── vpc/                   # VPC, subnets, IGW, NAT GW, route tables
    ├── security_groups/       # SG ALB → SG APP → SG RDS
    ├── ecr/                   # Registre Docker privé
    ├── iam/                   # Rôles ECS (moindre privilège)
    ├── secrets/               # Credentials RDS dans Secrets Manager
    ├── rds/                   # PostgreSQL Multi-AZ chiffré
    ├── alb/                   # Application Load Balancer HTTPS
    ├── ecs/                   # Fargate + Auto Scaling
    ├── cloudwatch/            # Logs, alarmes, dashboard
    └── budgets/               # Alerte budget AWS
```

## Réponses aux questions de défense

**Q1 : Que se passe-t-il si une AZ tombe ?**
→ RDS bascule automatiquement sur le standby (RTO < 1 min, RPO = 0). L'ALB redirige le trafic vers les tâches Fargate dans les AZ restantes. ECS Auto Scaling relance de nouvelles tâches si nécessaire.

**Q2 : Où est le mot de passe RDS ?**
→ Dans AWS Secrets Manager (`/petclinic-prod/rds/credentials`). L'application le lit via la variable d'environnement injectée par ECS au démarrage de la tâche — aucune clé en dur dans le code.

**Q3 : Pourquoi ECS Fargate et pas EC2 ?**
→ Fargate élimine la gestion des instances (patching, AMI). Scalabilité à la tâche, pas au serveur. Facturation à la seconde. Isolation réseau par tâche via awsvpc.

**Q4 : Comment l'application monte-t-elle en charge ?**
→ Application Auto Scaling sur la métrique `ECSServiceAverageCPUUtilization` (seuil 70%). Scale-out en 60s, scale-in en 300s pour éviter le yo-yo.

**Q5 : Coût mensuel estimé (db.t3.micro + 512 CPU / 1 Go Fargate x3) ?**
→ ~$45-60/mois (RDS ~$15, NAT GW ~$15, Fargate ~$10, ALB ~$5, autres ~$10). Réduction possible : RDS reserved instances, NAT GW partagé, Fargate Spot pour les tâches non critiques.
