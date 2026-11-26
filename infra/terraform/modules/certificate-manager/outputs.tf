output "certificate_map_name" {
  description = "Certificate map name referenced by networking.gke.io/certmap on the Gateway."
  value       = google_certificate_manager_certificate_map.portfolio.name
}

output "dns_authorization_record" {
  description = "CNAME record to add at your DNS provider to validate the managed TLS certificate."
  value       = google_certificate_manager_dns_authorization.portfolio.dns_resource_record[0]
}
