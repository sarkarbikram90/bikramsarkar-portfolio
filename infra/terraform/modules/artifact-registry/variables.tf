variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "Artifact Registry location."
  default     = "us-central1"
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry repository ID."
  default     = "portfolio-images"
}

variable "keep_recent_count" {
  type        = number
  description = "Number of most recent image versions retained by cleanup policy."
  default     = 10
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default = {
    managed-by = "terraform"
    project    = "portfolio-ops"
  }
}
