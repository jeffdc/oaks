# Oaks V2 Infrastructure
#
# This file documents all infrastructure provisioned for the Phoenix V2 app.
# Resources were initially created manually (2026-02-07) and are captured here
# for documentation. To bring under OpenTofu management, run `tofu import`.
#
# Existing V1 app (oak-compendium-api) is NOT managed here — do not modify it.

# -----------------------------------------------------------------------------
# Fly.io — App + Volume
# -----------------------------------------------------------------------------

resource "fly_app" "oaks" {
  name = var.fly_app_name
  org  = "personal"
}

resource "fly_volume" "data" {
  app    = fly_app.oaks.name
  name   = "oaks_data"
  region = var.fly_region
  size   = var.fly_volume_size_gb
}

# Fly.io secrets are set via CLI since the provider doesn't manage them:
#   flyctl secrets set LITESTREAM_ACCESS_KEY_ID=<key> --app oaks
#   flyctl secrets set LITESTREAM_SECRET_ACCESS_KEY=<secret> --app oaks
#   flyctl secrets set SECRET_KEY_BASE=<base64> --app oaks
#
# The machine configuration (vm size, mounts, http_service) is defined in
# fly.toml and applied at deploy time, not managed here.

# -----------------------------------------------------------------------------
# AWS — S3 bucket for Litestream backups
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "litestream_backups" {
  bucket = var.s3_bucket_name

  tags = {
    Project = "oaks"
    Purpose = "litestream-replication"
  }
}

resource "aws_s3_bucket_versioning" "litestream_backups" {
  bucket = aws_s3_bucket.litestream_backups.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "litestream_backups" {
  bucket = aws_s3_bucket.litestream_backups.id

  rule {
    id     = "expire-old-generations"
    status = "Enabled"

    # Litestream manages its own generations; clean up anything older than 30 days
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "litestream_backups" {
  bucket = aws_s3_bucket.litestream_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# AWS — IAM user + policy for Litestream
# -----------------------------------------------------------------------------

resource "aws_iam_user" "litestream" {
  name = "litestream-oaks"

  tags = {
    Project = "oaks"
    Purpose = "litestream-s3-replication"
  }
}

resource "aws_iam_policy" "litestream_backup" {
  name        = "LitestreamOaksBackup"
  description = "Allows Litestream to replicate SQLite WAL to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LitestreamBackups"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.litestream_backups.arn,
          "${aws_s3_bucket.litestream_backups.arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "litestream" {
  user       = aws_iam_user.litestream.name
  policy_arn = aws_iam_policy.litestream_backup.arn
}

resource "aws_iam_access_key" "litestream" {
  user = aws_iam_user.litestream.name
}
