################################################################################
# Module ECR – Registre privé d'images Docker
################################################################################

resource "aws_ecr_repository" "main" {
  name                 = "${var.name_prefix}/${var.project_name}"
  image_tag_mutability = "MUTABLE"
  force_delete = true # <--- Ajoute cette ligne
  image_scanning_configuration {
    scan_on_push = true  # Analyse de vulnérabilités à chaque push
  }

  encryption_configuration {
    encryption_type = "KMS"  # Chiffrement au repos avec KMS
  }

  tags = { Name = "${var.name_prefix}-ecr" }
}

# Politique de cycle de vie : conserver seulement les 10 dernières images
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conserver les 10 dernières images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
