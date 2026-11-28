variable "project_id" {
  type        = string
  description = "GCP Project ID for PortfolioOps."
}

variable "region" {
  type        = string
  description = "Primary GCP region (ADR-001 standardizes on us-central1)."
  default     = "us-central1"
}

variable "cluster_name" {
  type        = string
  description = "GKE Autopilot cluster name."
  default     = "portfolio-gke"
}

variable "domain" {
  type        = string
  description = "Public domain name served via GKE Gateway API."
  default     = "bikramsarkar.space"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository allowed to exchange OIDC tokens via WIF."
  default     = "sarkarbikram90/bikramsarkar-portfolio"
}

variable "artifact_registry_repository_id" {
  type        = string
  description = "Artifact Registry Docker repository ID."
  default     = "portfolio-images"
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Set true to make the GKE control plane private-only."
  default     = false
}

variable "master_authorized_cidrs" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "Authorized CIDRs allowed to access the GKE control plane endpoint (e.g., your workstation /32)."
  default     = []
}

variable "release_channel" {
  type        = string
  description = "GKE release channel (RAPID, REGULAR, STABLE)."
  default     = "REGULAR"
}

variable "binary_authorization_mode" {
  type        = string
  description = "Binary Authorization mode (PROJECT_SINGLETON_POLICY_ENFORCE blocks unattested custom images)."
  default     = "PROJECT_SINGLETON_POLICY_ENFORCE"
}

variable "deletion_protection" {
  type        = bool
  description = "Protect the GKE Autopilot cluster from accidental terraform destroy."
  default     = true
}

variable "billing_account_id" {
  type        = string
  description = "GCP Billing Account ID (optional; leave empty to skip budget creation)."
  default     = ""
}

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly GCP spend budget in USD (triggers alerts at 50%, 80%, 100%)."
  default     = 60
}

variable "alert_email" {
  type        = string
  description = "Email address for Cloud Monitoring incident alerts (optional)."
  default     = ""
}

variable "alert_webhook_url" {
  type        = string
  description = "Webhook URL for real-time Cloud Monitoring alerts (optional)."
  default     = ""
  sensitive   = true
}

variable "digest_job_image" {
  type        = string
  description = "Immutable Artifact Registry URI@sha256 for digest-job Cloud Run Job (set after first CI push)."
  default     = ""
}

variable "enable_digest_webhook_secret" {
  type        = bool
  description = "Mount the Secret Manager digest webhook secret via secret_key_ref after populating version 1 via gcloud."
  default     = false
}
