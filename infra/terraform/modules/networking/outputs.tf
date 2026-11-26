output "vpc_id" {
  description = "VPC network ID."
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "VPC network name."
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "GKE subnetwork ID."
  value       = google_compute_subnetwork.gke.id
}

output "subnet_name" {
  description = "GKE subnetwork name."
  value       = google_compute_subnetwork.gke.name
}

output "pods_range_name" {
  description = "Secondary IP range name for pods."
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Secondary IP range name for services."
  value       = var.services_range_name
}

output "gateway_static_ip_name" {
  description = "Reserved global static IP resource name."
  value       = google_compute_global_address.gateway_ip.name
}

output "gateway_static_ip_address" {
  description = "Reserved global external IPv4 address for DNS A record."
  value       = google_compute_global_address.gateway_ip.address
}
