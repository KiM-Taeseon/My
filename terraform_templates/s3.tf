resource "aws_s3_bucket" "example" {
  count = var.bucket_count
  bucket = "s3-${var.user_name}-${count.index}"

  tags = {
    Name = "s3-${var.user_name}-${count.index}"
  }
}