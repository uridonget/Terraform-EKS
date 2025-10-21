# 02-addons/variables.tf

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
  default     = ""
}

variable "istio_enabled_namespaces" {
  description = "List of namespaces where Istio sidecar injection should be enabled"
  type        = list(string)
  default     = ["default",""]
}

variable "route53_hosted_zone_ids" {
  description = "List of Route53 hosted zone IDs that External-DNS should manage (optional)"
  type        = list(string)
  default     = [""]
}

variable "grafana_admin_password" {
  description = "Password of Grafana Admin"
  type        = string
  default     = ""
}