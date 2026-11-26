output "cluster_name" {
  description = "GKE Autopilot cluster name."
  value       = module.gke_autopilot.cluster_name
}

output "cluster_location" {
  description = "GKE Autopilot cluster region."
  value       = module.gke_autopilot.cluster_location
}

output "kubectl_credentials_command" {
  description = "Run this command to configure kubectl for the cluster."
  value       = module.gke_autopilot.get_credentials_command
}

output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL."
  value       = module.artifact_registry.repository_url
}

output "gateway_static_ip" {
  description = "Global static IPv4 address — point your DNS A record here after Gateway & TLS are ACTIVE."
  value       = module.networking.gateway_static_ip_address
}

output "certificate_map_name" {
  description = "Certificate Manager map name referenced by GKE Gateway."
  value       = module.certificate_manager.certificate_map_name
}

output "dns_authorization_cname" {
  description = "Add this CNAME record at your DNS registrar to issue the Google-managed TLS certificate."
  value       = module.certificate_manager.dns_authorization_record
}

output "github_wif_provider" {
  description = "GitHub Actions Workload Identity Provider resource name."
  value       = module.workload_identity_github.workload_identity_provider
}

output "github_ci_service_account" {
  description = "GitHub Actions least-privilege Artifact Registry publisher service account."
  value       = module.workload_identity_github.service_account_email
}

output "availability_slo_name" {
  description = "Cloud Monitoring 99.9% availability SLO resource name."
  value       = module.observability.availability_slo_name
}

output "sre_dashboard_id" {
  description = "Cloud Monitoring SRE Overview dashboard ID."
  value       = module.observability.sre_dashboard_id
}

output "analytics_pubsub_topic" {
  description = "Pub/Sub topic ID for visitor events."
  value       = module.analytics_pipeline.pubsub_topic_id
}

output "analytics_bigquery_table" {
  description = "BigQuery table receiving streamed visitor events."
  value       = module.analytics_pipeline.bigquery_table_fqn
}

output "analytics_workload_sa_email" {
  description = "GCP Service Account email to annotate on the analytics-api Kubernetes ServiceAccount."
  value       = module.analytics_pipeline.analytics_service_account_email
}
