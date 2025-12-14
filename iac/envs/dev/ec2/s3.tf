
# S3 Bucket for Backups (Publicly Readable - Weakness)
resource "aws_s3_bucket" "backups" {
  bucket_prefix = "wiz-mongo-backups-"
  force_destroy = true

  tags = local.tags
}

# Explicitly remove "Block Public Access" to allow public policies
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy for Public Read and List
resource "aws_s3_bucket_policy" "public_read" {
  bucket     = aws_s3_bucket.backups.id
  depends_on = [aws_s3_bucket_public_access_block.backups]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadAndList"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backups.arn,
          "${aws_s3_bucket.backups.arn}/*"
        ]
      }
    ]
  })
}


