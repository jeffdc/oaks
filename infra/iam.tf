# The user the app signs in as to store and remove species photos.
#
# Its access key is NOT managed here, so its secret never enters tofu state:
# create it with `aws iam create-access-key` and put it straight into Fly
# secrets (README.md). The bucket lifecycle, not this user, removes old
# versions, so it needs no s3:DeleteObjectVersion.

resource "aws_iam_user" "images_upload" {
  name = "oaks-images-upload"

  tags = {
    Project   = "oaks"
    ManagedBy = "opentofu"
  }
}

resource "aws_iam_policy" "images_upload" {
  name        = "OaksImagesUpload"
  description = "Store and remove species photos and invalidate their CloudFront paths"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ImageObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.images.arn}/*"
      },
      {
        Sid      = "ImageBucketList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.images.arn
      },
      {
        Sid      = "ImageInvalidation"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
        Resource = aws_cloudfront_distribution.images.arn
      }
    ]
  })

  tags = {
    Project   = "oaks"
    ManagedBy = "opentofu"
  }
}

resource "aws_iam_user_policy_attachment" "images_upload" {
  user       = aws_iam_user.images_upload.name
  policy_arn = aws_iam_policy.images_upload.arn
}
