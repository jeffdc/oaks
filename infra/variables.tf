variable "aws_region" {
  description = "AWS region for all resources (matches Fly's iad)"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "S3 bucket for Litestream backups"
  type        = string
  default     = "oaks-db-backups"
}

variable "images_domain" {
  description = "Custom domain the images distribution serves (CNAME at Porkbun)"
  type        = string
  default     = "images.oakcompendium.org"
}
