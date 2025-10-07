# 01-cluster/variables.tf

variable "name_prefix" {
  description = "A prefix for all resources in the cluster for uniqueness."
  type        = string
  default     = "haechan-eks"
}

variable "region" {
  description = "AWS region for the cluster."
  type        = string
  default     = "ap-northeast-2"
}