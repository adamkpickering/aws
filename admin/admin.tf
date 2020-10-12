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

resource "aws_iam_access_key" "general_user_key" {
  user = aws_iam_user.general_user.name
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
      "Action": "*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": "Billing:*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": "iam:*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "sns:List*",
        "sns:Check*",
        "sns:Get*",
        "sns:TagResource",
        "sns:UntagResource",
        "sns:Create*",
        "sns:Confirm*",
        "sns:Delete*",
        "sns:Set*",
        "sns:OptInPhoneNumber",
        "sns:Subscribe*",
        "sns:Unsubscribe",
        "sns:*Permission"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
