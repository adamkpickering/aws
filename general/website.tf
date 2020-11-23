terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
  backend "s3" {
    profile = "default"
    region  = "ca-central-1"
    bucket  = "adampickering-terraform"
    key     = "general.state"
  }
}

locals {
  website_name = "adampickering.ca"
  website_dir  = "../../website/public"
}

provider "aws" {
  profile = "default"
  region  = "ca-central-1"
}

provider "aws" {
  alias   = "us-east-1"
  profile = "default"
  region  = "us-east-1"
}



# DNS CONFIG

resource "aws_route53_zone" "root" {
  name = local.website_name
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.root.zone_id
  name    = local.website_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.root.zone_id
  name    = "www.${local.website_name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}



# S3 BUCKET CONFIG

resource "aws_s3_bucket" "website" {
  bucket        = local.website_name
  force_destroy = true
  acl           = "private"

  website {
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_object" "website_file_html" {
  for_each     = fileset(local.website_dir, "**.html")
  bucket       = aws_s3_bucket.website.id
  key          = each.key
  source       = "${local.website_dir}/${each.key}"
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "website_file_css" {
  for_each     = fileset(local.website_dir, "**.css")
  bucket       = aws_s3_bucket.website.id
  key          = each.key
  source       = "${local.website_dir}/${each.key}"
  content_type = "text/css"
}

resource "aws_s3_bucket_object" "website_file_xml" {
  for_each     = fileset(local.website_dir, "**.xml")
  bucket       = aws_s3_bucket.website.id
  key          = each.key
  source       = "${local.website_dir}/${each.key}"
  content_type = "text/xml"
}



# ACM CERTIFICATE CONFIG

resource "aws_acm_certificate" "website" {
  provider                  = aws.us-east-1
  domain_name               = "www.${local.website_name}"
  subject_alternative_names = toset([local.website_name])
  validation_method         = "DNS"
}

resource "aws_route53_record" "cert" {
  for_each = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.root.zone_id
}

resource "aws_acm_certificate_validation" "website" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for record in aws_route53_record.cert : record.fqdn]
}



# CLOUDFRONT CONFIG
# An OAI (Origin Access Identity) is used to allow cloudfront access to the s3 bucket
# while preventing other parties from accessing it. It is essentially a special
# cloudfront user, to which we assign a policy which gives it access to the s3 bucket.

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "For ${local.website_name}"
}

data "aws_iam_policy_document" "website_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.website.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website_s3_policy.json
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_200"
  http_version        = "http2"
  default_root_object = "index.html"
  aliases = [local.website_name, "www.${local.website_name}"]

  origin {
    domain_name = aws_s3_bucket.website.bucket_domain_name
    origin_id   = "origin-bucket-${aws_s3_bucket.website.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "origin-bucket-${aws_s3_bucket.website.id}"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.website.certificate_arn
    minimum_protocol_version = "TLSv1"
    ssl_support_method       = "sni-only"
  }
}
