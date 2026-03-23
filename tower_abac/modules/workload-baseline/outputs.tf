output "workload_access_role_arn" {
  value = aws_iam_role.workload_access.arn
}

output "example_bucket_name" {
  value = aws_s3_bucket.example_workload.bucket
}