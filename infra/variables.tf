variable "fly_region" {
  description = "Fly.io region for the app and volume"
  type        = string
  default     = "iad"
}

variable "fly_app_name" {
  description = "Fly.io app name"
  type        = string
  default     = "oaks"
}

variable "fly_volume_size_gb" {
  description = "Size of the Fly.io volume in GB"
  type        = number
  default     = 1
}

variable "s3_bucket_name" {
  description = "S3 bucket for Litestream backups"
  type        = string
  default     = "oaks-db-backups"
}

variable "s3_region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "secret_key_base" {
  description = "Phoenix SECRET_KEY_BASE (generate with: openssl rand -base64 48)"
  type        = string
  sensitive   = true
}
