locals {
  prefix = "${var.project}-${var.environment}"
}
# CloudFront creation is restricted until AWS verifies this new account.
# The production fallback serves web + API from the existing EC2 HTTPS host.
variable "enable_cloudfront" {
  type = bool
  default = false
}
resource "aws_s3_bucket" "web" {
  bucket_prefix = "${local.prefix}-web-"
  tags = {
    Project = var.project
    Environment = var.environment
  }
}
resource "aws_s3_bucket_public_access_block" "web" {
  bucket = aws_s3_bucket.web.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "web" {
  bucket = aws_s3_bucket.web.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_cloudfront_origin_access_control" "web" {
  name = "${local.prefix}-web"
  description = "Private S3 origin for WeuTube web"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}
resource "aws_cloudfront_distribution" "web" {
  count = var.enable_cloudfront ? 1 : 0
  enabled = true
  default_root_object = "index.html"
  origin {
    domain_name = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id = "weutube-web"
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }
  default_cache_behavior {
    target_origin_id = "weutube-web"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = {
    Project = var.project
    Environment = var.environment
  }
}
data "aws_iam_policy_document" "web" {
  count = var.enable_cloudfront ? 1 : 0
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web.arn}/*"]
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.web[0].arn]
    }
  }
}
resource "aws_s3_bucket_policy" "web" {
  count = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.web.id
  policy = data.aws_iam_policy_document.web[0].json
  depends_on = [aws_s3_bucket_public_access_block.web]
}
output "web_bucket" {
  value = aws_s3_bucket.web.id
}
output "cloudfront_domain" {
  value = var.enable_cloudfront ? aws_cloudfront_distribution.web[0].domain_name : null
}
