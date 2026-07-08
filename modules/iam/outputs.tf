output "ecs_execution_role_arn" { value = aws_iam_role.ecs_execution.arn }
output "ecs_task_role_arn" { value = aws_iam_role.ecs_task.arn }

output "certificate_arn" {
  description = "ARN du certificat SSL/TLS généré et téléversé automatiquement"
  value       = aws_iam_server_certificate.petclinic_automated_cert.arn
}
