output "s3_bucket_name" {
  description = "S3 bucket for Litestream backups"
  value       = aws_s3_bucket.litestream_backups.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.litestream_backups.arn
}

# The secret is only known when a key is created, so imported keys have none in
# state. It lives in Fly secrets (LITESTREAM_SECRET_ACCESS_KEY).
output "litestream_access_key_id" {
  description = "Access key ID for the Litestream IAM user (set as a Fly secret)"
  value       = aws_iam_access_key.litestream.id
  sensitive   = true
}
