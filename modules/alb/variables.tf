variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "sg_alb_id" { type = string }
variable "container_port" { type = number }
variable "certificate_arn" {
  type    = string
  default = ""
}
variable "domain_name" {
  type    = string
  default = ""
}
