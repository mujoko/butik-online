provider "aws" {
  region = var.region
}

# S3 bucket to store Terraform state
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name
  force_destroy = false

  tags = {
    Name        = var.state_bucket_name
    ManagedBy   = "Terraform"
    Purpose     = "tfstate"
    Project     = "butik-online-eks"
    Environment = "demo"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = var.lock_table_name
    ManagedBy   = "Terraform"
    Purpose     = "tflock"
    Project     = "butik-online-eks"
    Environment = "demo"
  }
}
