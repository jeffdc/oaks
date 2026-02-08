output "fly_app_name" {
  description = "Fly.io app name"
  value       = fly_app.oaks.name
}

output "fly_app_hostname" {
  description = "Fly.io app hostname"
  value       = "${fly_app.oaks.name}.fly.dev"
}

output "s3_bucket_name" {
  description = "S3 bucket for Litestream backups"
  value       = aws_s3_bucket.litestream_backups.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.litestream_backups.arn
}

output "litestream_access_key_id" {
  description = "Access key ID for Litestream IAM user (set as Fly secret)"
  value       = aws_iam_access_key.litestream.id
  sensitive   = true
}

output "litestream_secret_access_key" {
  description = "Secret access key for Litestream IAM user (set as Fly secret)"
  value       = aws_iam_access_key.litestream.secret
  sensitive   = true
}
