output "digest_job_service_account" {
  description = "Least-privilege BigQuery reader and Secret Manager accessor SA for the Cloud Run daily digest job."
  value       = google_service_account.digest_job.email
}

output "digest_job_name" {
  description = "Cloud Run v2 Job name (null until digest_image is configured)."
  value       = try(google_cloud_run_v2_job.daily_digest[0].name, null)
}

output "digest_webhook_secret_id" {
  description = "Secret Manager secret ID for the daily digest webhook URL."
  value       = google_secret_manager_secret.digest_webhook.secret_id
}

output "add_webhook_secret_command" {
  description = "Populate the webhook secret out-of-band without storing plaintext in Terraform state."
  value       = "printf '%s' '<WEBHOOK_URL>' | gcloud secrets versions add ${google_secret_manager_secret.digest_webhook.secret_id} --project=${var.project_id} --data-file=-"
}
