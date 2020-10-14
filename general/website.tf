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

provider "aws" {
  profile = "default"
  region  = "ca-central-1"
}

resource "aws_route53_zone" "root" {
  name = "adampickering.ca"
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.root.zone_id
  name = "adampickering.ca"
  type = "A"
  ttl = "300"
  records = ["108.173.251.186"]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.root.zone_id
  name = "www.adampickering.ca"
  type = "A"
  ttl = "300"
  records = ["108.173.251.186"]
}
