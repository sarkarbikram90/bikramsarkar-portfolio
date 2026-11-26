output "digest_job_service_account" {
  description = "Least-privilege BigQuery reader SA for the Cloud Run daily digest job."
  value       = google_service_account.digest_job.email
}

output "digest_job_name" {
  description = "Cloud Run v2 Job name (null until digest_image is configured)."
  value       = try(google_cloud_run_v2_job.daily_digest[0].name, null)
}
