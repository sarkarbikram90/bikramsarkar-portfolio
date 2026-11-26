output "cluster_name" {
  description = "GKE Autopilot cluster name."
  value       = google_container_cluster.autopilot.name
}

output "cluster_location" {
  description = "GKE Autopilot cluster region."
  value       = google_container_cluster.autopilot.location
}

output "cluster_endpoint" {
  description = "GKE control plane endpoint."
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "node_service_account_email" {
  description = "Least-privilege service account email assigned to GKE Autopilot nodes."
  value       = google_service_account.gke_nodes.email
}

output "get_credentials_command" {
  description = "Command to configure kubectl for this cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.autopilot.name} --region ${google_container_cluster.autopilot.location} --project ${var.project_id}"
}
