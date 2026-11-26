variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "domain" {
  type        = string
  description = "Primary domain name for the managed certificate."
  default     = "bikramsarkar.space"
}

variable "name_prefix" {
  type        = string
  description = "Resource naming prefix."
  default     = "portfolio"
}

variable "certificate_map_name" {
  type        = string
  description = "Certificate Manager map name referenced by GKE Gateway annotation."
  default     = "portfolio-cert-map"
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default = {
    managed-by = "terraform"
    project    = "portfolio-ops"
  }
}
