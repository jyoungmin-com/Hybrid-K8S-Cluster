terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

resource "random_id" "cluster_uuid" {
  byte_length = 4
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${random_id.cluster_uuid.hex}"
  force_destroy = true

  tags = {
    "ManagedBy" = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "tfstate-versioning" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform-backend-lock" {
  name = "${var.project_name}-tfstate-lock-${random_id.cluster_uuid.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    "ManagedBy" = "terraform-bootstrap"
  }
}

output "cluster_uuid" {
  value = random_id.cluster_uuid.hex
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.id
}

output "lock_table" {
  value = aws_dynamodb_table.terraform-backend-lock.name
}