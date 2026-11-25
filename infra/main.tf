# Oaks infrastructure on AWS. Resources made by hand before OpenTofu managed
# them were brought in with `tofu import` (README.md). Fly is not managed here:
# the app is configured by fly.toml and its secrets by `fly secrets`.
#
# The V1 app (oak-compendium-api) is NOT managed here; do not modify it.

# -----------------------------------------------------------------------------
# AWS — S3 bucket for Litestream backups
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "litestream_backups" {
  bucket = var.s3_bucket_name
}

# Never versioned: Litestream keeps its own generations. "Disabled" is only
# valid for a bucket that has never had versioning on.
resource "aws_s3_bucket_versioning" "litestream_backups" {
  bucket = aws_s3_bucket.litestream_backups.id

  versioning_configuration {
    status = "Disabled"
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
