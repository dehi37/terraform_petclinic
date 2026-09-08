variable "name_prefix" { type = string }
variable "db_subnet_ids" { type = list(string) }
variable "sg_rds_id" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "db_engine_version" { type = string }
