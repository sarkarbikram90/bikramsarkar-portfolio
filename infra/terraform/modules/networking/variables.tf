variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region for VPC subnet and Cloud NAT."
  default     = "us-central1"
}

variable "name_prefix" {
  type        = string
  description = "Resource naming prefix."
  default     = "portfolio"
}

variable "subnet_cidr" {
  type        = string
  description = "Primary CIDR block for GKE nodes."
  default     = "10.10.0.0/20"
}

variable "pods_range_name" {
  type        = string
  description = "Secondary IP range name for GKE pods."
  default     = "gke-pods"
}

variable "pods_cidr" {
  type        = string
  description = "Secondary CIDR block for GKE pods."
  default     = "10.20.0.0/16"
}

variable "services_range_name" {
  type        = string
  description = "Secondary IP range name for GKE services."
  default     = "gke-services"
}

variable "services_cidr" {
  type        = string
  description = "Secondary CIDR block for GKE services."
  default     = "10.30.0.0/20"
}

variable "gateway_static_ip_name" {
  type        = string
  description = "Name of the reserved global IPv4 address for GKE Gateway."
  default     = "portfolio-ip"
}
