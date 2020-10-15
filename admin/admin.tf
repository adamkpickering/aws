terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
  backend "s3" {
    profile = "admin"
    region  = "ca-central-1"
    bucket  = "adampickering-terraform"
    key     = "admin.state"
  }
}

provider "aws" {
  profile = "admin"
  region  = "ca-central-1"
}

resource "aws_iam_user" "general_user" {
  name          = "general"
  force_destroy = true
}

resource "aws_iam_user_policy" "general_policy" {
  name   = "general"
  user   = aws_iam_user.general_user.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "ec2:*",
        "route53:*",
        "kms:*",
        "dynamodb:*",
        "acm:*",
        "cloudfront:*",
        "sns:Publish"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_kms_key" "unicreds" {
  description = "unicreds"
}

resource "aws_kms_alias" "unicreds" {
  name = "alias/credstash"
  target_key_id = aws_kms_key.unicreds.key_id
}
