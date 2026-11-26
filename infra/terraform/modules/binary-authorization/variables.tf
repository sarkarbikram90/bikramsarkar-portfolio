variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region for the KMS key ring."
  default     = "us-central1"
}

variable "name_prefix" {
  type        = string
  description = "Resource naming prefix."
  default     = "portfolio"
}

variable "ci_service_account_email" {
  type        = string
  description = "GitHub Actions CI service account granted KMS signing and Container Analysis note attach rights."
}

variable "infrastructure_image_allowlist" {
  type        = list(string)
  description = "Pinned third-party cluster infrastructure image patterns exempt from custom CI attestation."
  default = [
    "quay.io/argoproj/argocd:*",
    "public.ecr.aws/docker/library/redis:*",
    "docker.io/nginx/nginx-prometheus-exporter:*",
    "nginx/nginx-prometheus-exporter:*"
  ]
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default = {
    managed-by = "terraform"
    project    = "portfolio-ops"
  }
}
