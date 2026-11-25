# CloudFront distribution serving species photos on images.oakcompendium.org
# from the private images bucket.
#
# Image paths are unique per import attempt, so objects never change in place
# and can be cached for a long time. Removing a photo deletes its objects and
# then invalidates their paths (iam.tf lets the app do both).

resource "aws_cloudfront_origin_access_control" "images" {
  name                              = "oaks-images"
  description                       = "OAC for the oaks-images bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Long edge TTL whatever headers an object carries. No cookies, headers,
# query strings or encodings in the cache key: an image is its path, and
# photos are already compressed.
resource "aws_cloudfront_cache_policy" "images" {
  name        = "OaksImages"
  comment     = "One-year cache for immutable species photo paths"
  min_ttl     = 0
  default_ttl = 31536000
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "images" {
  comment         = "Oak Compendium species photos"
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"
  aliases         = [var.images_domain]

  origin {
    domain_name              = aws_s3_bucket.images.bucket_regional_domain_name
    origin_id                = "s3-images"
    origin_access_control_id = aws_cloudfront_origin_access_control.images.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-images"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false
    cache_policy_id        = aws_cloudfront_cache_policy.images.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.images.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project   = "oaks"
    ManagedBy = "opentofu"
  }
}
