terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ----------------------------------------------------------------------------
# Intentionally insecure — demo fixture for tf-analyze.
# Do NOT use as a reference for real infrastructure.
# ----------------------------------------------------------------------------

# Public S3 bucket — no encryption, no versioning, public ACL.
resource "aws_s3_bucket" "public_data" {
  bucket = "tf-analyze-demo-public-data"
}

resource "aws_s3_bucket_acl" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "public_data" {
  bucket                  = aws_s3_bucket.public_data.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Security group open to the world on SSH and RDP.
resource "aws_security_group" "wide_open" {
  name        = "tf-analyze-demo-wide-open"
  description = "Demo: ingress 0.0.0.0/0"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS instance — publicly accessible, no encryption, hardcoded password.
resource "aws_db_instance" "demo" {
  identifier             = "tf-analyze-demo-db"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "admin"
  password               = "SuperSecret123!" # tfsec:ignore intentional
  publicly_accessible    = true
  storage_encrypted      = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.wide_open.id]
}

# IAM role with star:star permissions.
resource "aws_iam_role" "admin" {
  name = "tf-analyze-demo-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "star_star" {
  name = "star-star"
  role = aws_iam_role.admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# EC2 instance attached to the wide-open SG and the admin role.
resource "aws_iam_instance_profile" "admin" {
  name = "tf-analyze-demo-admin"
  role = aws_iam_role.admin.name
}

resource "aws_instance" "demo" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.wide_open.id]
  iam_instance_profile        = aws_iam_instance_profile.admin.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "optional" # IMDSv1 allowed — insecure
  }

  root_block_device {
    encrypted = false
  }
}
