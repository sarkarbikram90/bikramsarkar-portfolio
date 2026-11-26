output "workload_identity_provider" {
  description = "Full WIF provider resource name for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "CI publisher service account email for google-github-actions/auth."
  value       = google_service_account.ci_publisher.email
}
