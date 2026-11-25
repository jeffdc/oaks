# Certificate for images.oakcompendium.org. CloudFront needs it in us-east-1
# (the provider's region). DNS is at Porkbun, outside tofu: add the CNAME from
# the images_cert_validation output there. The validation resource waits until
# the certificate is issued.

resource "aws_acm_certificate" "images" {
  domain_name       = var.images_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project   = "oaks"
    ManagedBy = "opentofu"
  }
}

resource "aws_acm_certificate_validation" "images" {
  certificate_arn = aws_acm_certificate.images.arn
}
