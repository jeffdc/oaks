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

output "images_bucket_name" {
  description = "S3 bucket for species photos"
  value       = aws_s3_bucket.images.bucket
}

output "images_cert_validation" {
  description = "CNAME to add at Porkbun so ACM issues the images certificate"
  value = [
    for o in aws_acm_certificate.images.domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ]
}

output "images_distribution_domain" {
  description = "Target of the images CNAME at Porkbun"
  value       = aws_cloudfront_distribution.images.domain_name
}

output "images_distribution_id" {
  description = "Distribution ID the app invalidates paths on (runtime config)"
  value       = aws_cloudfront_distribution.images.id
}
