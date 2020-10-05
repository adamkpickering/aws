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
    key     = "terraform.state"
  }
}

provider "aws" {
  profile = "default"
  region  = "ca-central-1"
}

resource "aws_route53_zone" "root_zone" {
  name = "adampickering.ca"
}
