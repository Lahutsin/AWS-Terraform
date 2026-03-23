output "permission_sets" {
  value = {
    platform_admin    = aws_ssoadmin_permission_set.platform_admin.arn
    workload_operator = aws_ssoadmin_permission_set.workload_operator.arn
    audit_readonly    = aws_ssoadmin_permission_set.audit_readonly.arn
  }
}