output "pubsub_topic_id" {
  description = "Pub/Sub topic ID for Go analytics-api PUBSUB_TOPIC_ID env var."
  value       = google_pubsub_topic.visitor_events.name
}

output "bigquery_table_fqn" {
  description = "Fully-qualified BigQuery table name (project.dataset.table)."
  value       = "${var.project_id}.${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.visitor_events.table_id}"
}

output "analytics_service_account_email" {
  description = "GCP Service Account email for Kubernetes Workload Identity annotation."
  value       = google_service_account.analytics_api.email
}
