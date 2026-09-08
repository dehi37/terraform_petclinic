################################################################################
# Module Security Groups
# Chaîne : SG ALB → SG APP → SG RDS (aucun port d'admin ouvert sur Internet)
################################################################################

# ── SG ALB : accepte HTTPS (443) et HTTP (80 → redirect) depuis Internet ─────
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-sg-alb"
  description = "Security Group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from Internet - redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound to ECS tasks"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    self        = false
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-alb" }
}

# ── SG APP : accepte uniquement le trafic provenant du SG ALB ────────────────
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-sg-app"
  description = "Security Group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "Outbound Internet via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-app" }
}

# Règle d'entrée séparée pour éviter la référence circulaire
resource "aws_security_group_rule" "app_from_alb" {
  type                     = "ingress"
  description              = "Traffic from ALB SG only"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
}

# ── SG RDS : accepte uniquement le trafic provenant du SG APP ────────────────
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-sg-rds"
  description = "Security Group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  egress {
    description = "No outbound traffic required"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-rds" }
}

resource "aws_security_group_rule" "rds_from_app" {
  type                     = "ingress"
  description              = "PostgreSQL from APP SG only"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.app.id
}
