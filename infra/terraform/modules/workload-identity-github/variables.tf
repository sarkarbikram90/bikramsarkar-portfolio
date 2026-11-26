variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository in owner/name format."
  default     = "sarkarbikram90/bikramsarkar-portfolio"
}

variable "restrict_to_main_branch" {
  type        = bool
  description = "Restrict OIDC token exchange strictly to refs/heads/main."
  default     = true
}

variable "pool_id" {
  type        = string
  description = "Workload Identity Pool ID."
  default     = "github-actions-pool"
}

variable "provider_id" {
  type        = string
  description = "Workload Identity Provider ID."
  default     = "github-oidc"
}

variable "service_account_id" {
  type        = string
  description = "Service account ID for GitHub Actions image publishing."
  default     = "github-ci-publisher"
}

variable "artifact_registry_location" {
  type        = string
  description = "Location of the Artifact Registry repository."
  default     = "us-central1"
}

variable "artifact_registry_repository_id" {
  type        = string
  description = "Artifact Registry repository ID."
}
