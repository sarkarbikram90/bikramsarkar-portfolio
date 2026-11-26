variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region for the GKE Autopilot cluster."
  default     = "us-central1"
}

variable "cluster_name" {
  type        = string
  description = "GKE Autopilot cluster name."
  default     = "portfolio-gke"
}

variable "vpc_id" {
  type        = string
  description = "VPC network self-link or ID."
}

variable "subnet_id" {
  type        = string
  description = "Subnetwork self-link or ID."
}

variable "pods_range_name" {
  type        = string
  description = "Secondary IP range name for pods."
}

variable "services_range_name" {
  type        = string
  description = "Secondary IP range name for services."
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Keep control plane endpoint private-only (requires bastion/VPN to run kubectl)."
  default     = false
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "Dedicated /28 CIDR block for the GKE control plane."
  default     = "172.16.0.0/28"
}

variable "master_authorized_cidrs" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "CIDR blocks authorized to reach the GKE control plane endpoint (e.g., your workstation /32)."
  default     = []
}

variable "release_channel" {
  type        = string
  description = "GKE release channel (RAPID, REGULAR, or STABLE)."
  default     = "REGULAR"
}

variable "binary_authorization_mode" {
  type        = string
  description = "Binary Authorization evaluation mode (DISABLED or PROJECT_SINGLETON_POLICY_ENFORCE)."
  default     = "DISABLED"
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental cluster deletion via Terraform."
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Resource labels applied to the cluster."
  default = {
    managed-by = "terraform"
    project    = "portfolio-ops"
  }
}
