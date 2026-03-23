output "log_archive_bucket_name" {
  value = aws_s3_bucket.log_archive.bucket
}

output "cloudtrail_kms_key_arn" {
  value = aws_kms_key.cloudtrail.arn
}