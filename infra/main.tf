locals {
  # Escape text before including it in HTML, including ampersands first.
  escaped_ampersands = replace(trimspace(var.site_owner), "&", "&amp;")
  escaped_brackets   = replace(replace(local.escaped_ampersands, "<", "&lt;"), ">", "&gt;")
  escaped_owner      = replace(replace(local.escaped_brackets, "\"", "&quot;"), "'", "&#39;")

  html = templatefile("${path.module}/../site/index.html.tftpl", {
    site_owner = local.escaped_owner
  })
}

resource "aws_s3_bucket" "site" {
  bucket_prefix = "infra-eng-challenge-"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "index" {
  bucket        = aws_s3_bucket.site.id
  key           = "index.html"
  content       = local.html
  content_type  = "text/html; charset=utf-8"
  cache_control = "public, max-age=60, s-maxage=60"

  depends_on = [
    aws_s3_bucket_public_access_block.site,
    aws_s3_bucket_ownership_controls.site,
    aws_s3_bucket_server_side_encryption_configuration.site,
  ]
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = aws_s3_bucket.site.id
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "site" {
  name        = aws_s3_bucket.site.id
  min_ttl     = 0
  default_ttl = 60
  max_ttl     = 300

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

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

resource "aws_cloudfront_response_headers_policy" "site" {
  name = aws_s3_bucket.site.id

  security_headers_config {
    content_security_policy {
      content_security_policy = "default-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
      override                = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "no-referrer"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      override                   = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  wait_for_deployment = true
  comment             = "Static website"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = "site"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.site.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowDistributionRead"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = aws_s3_object.index.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn"     = aws_cloudfront_distribution.site.arn
            "AWS:SourceAccount" = var.aws_account_id
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.site.arn, "${aws_s3_bucket.site.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}
