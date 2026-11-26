variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "domain" {
  type        = string
  description = "Public domain monitored by external HTTPS uptime checks."
  default     = "bikramsarkar.space"
}

variable "cluster_name" {
  type        = string
  description = "GKE Autopilot cluster name for container alerts and dashboards."
  default     = "portfolio-gke"
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace hosting portfolio workloads."
  default     = "portfolio"
}

variable "github_repository" {
  type        = string
  description = "GitHub repo (owner/name) used to link alerts to runbooks."
  default     = "sarkarbikram90/bikramsarkar-portfolio"
}

variable "alert_email" {
  type        = string
  description = "Email address for Cloud Monitoring alert notifications (optional)."
  default     = ""
}

variable "alert_webhook_url" {
  type        = string
  description = "Webhook URL (e.g. Google Chat / Slack relay) for alert notifications (optional)."
  default     = ""
  sensitive   = true
}
