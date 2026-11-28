variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region for Cloud Run Job and Cloud Scheduler."
  default     = "us-central1"
}

variable "bigquery_dataset_id" {
  type        = string
  description = "BigQuery dataset ID containing visitor_events."
  default     = "portfolio_analytics"
}

variable "bigquery_table_id" {
  type        = string
  description = "BigQuery table ID containing visitor_events."
  default     = "visitor_events"
}

variable "digest_image" {
  type        = string
  description = "Immutable Artifact Registry URI@sha256 for digest-job (leave empty before initial CI image push)."
  default     = ""
}

variable "webhook_secret_id" {
  type        = string
  description = "Secret Manager secret ID storing the daily digest webhook URL."
  default     = "portfolio-digest-webhook-url"
}

variable "enable_webhook_secret" {
  type        = bool
  description = "Attach the Secret Manager secret_key_ref to Cloud Run Job after populating version 1 via gcloud."
  default     = false
}

variable "webhook_secret_version" {
  type        = string
  description = "Secret Manager version to mount into DIGEST_WEBHOOK_URL."
  default     = "latest"
}

variable "schedule_cron" {
  type        = string
  description = "UTC cron schedule for the daily visitor digest."
  default     = "0 8 * * *"
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default = {
    managed-by = "terraform"
    project    = "portfolio-ops"
  }
}
