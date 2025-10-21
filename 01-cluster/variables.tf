# 01-cluster/variables.tf

variable "name_prefix" {
  description = "A prefix for all resources in the cluster for uniqueness."
  type        = string
  default     = ""
}

variable "user_db_env" {
  description = "User DB environment variables"
  type = object({
    user     = string
    password = string
    db_name  = string
  })
  default = {
    user     = ""
    password = ""
    db_name  = ""
  }
  sensitive = true
}

variable "redis_db_args" {
  description = "Redis DB arguments"
  type        = string
  default     = "--requirepass "
  sensitive   = true
}

variable "region" {
  description = "AWS region for the cluster."
  type        = string
  default     = "ap-northeast-2"
}
