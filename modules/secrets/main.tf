################################################################################
# Module Secrets Manager
# Génère et stocke le mot de passe RDS – jamais en dur dans le code
################################################################################

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name_prefix}/rds/credentials"
  description = "Credentials PostgreSQL pour Spring PetClinic"

  # AJOUTE CETTE LIGNE :
  recovery_window_in_days = 0 # Désactive la corbeille (suppression immédiate au destroy)
  tags = { Name = "${var.name_prefix}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
    engine   = "postgres"
    port     = 5432
  })
}
