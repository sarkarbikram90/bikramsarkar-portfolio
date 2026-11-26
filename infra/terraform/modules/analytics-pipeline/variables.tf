variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "project_number" {
  type        = string
  description = "Numerical GCP project number (for Pub/Sub managed service agent IAM)."
}

variable "dataset_id" {
  type        = string
  description = "BigQuery dataset ID."
  default     = "portfolio_analytics"
}

variable "table_id" {
  type        = string
  description = "BigQuery table ID for visitor events."
  default     = "visitor_events"
}

variable "bigquery_location" {
  type        = string
  description = "BigQuery dataset location (US aligns with us-central1)."
  default     = "US"
}

variable "topic_id" {
  type        = string
  description = "Pub/Sub topic ID for visitor events."
  default     = "portfolio-visitor-events"
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace for Workload Identity binding."
  default     = "portfolio"
}

variable "k8s_service_account" {
  type        = string
  description = "Kubernetes ServiceAccount name for Workload Identity binding."
  default     = "analytics-api"
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion of the BigQuery visitor_events table."
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default = {
    managed-by = "terraform"
    project    = "portfolio-ops"
  }
}
