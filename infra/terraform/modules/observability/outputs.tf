output "homepage_uptime_check_id" {
  description = "External HTTPS homepage uptime check ID."
  value       = google_monitoring_uptime_check_config.homepage.uptime_check_id
}

output "availability_slo_name" {
  description = "Full resource name of the 99.9% rolling 30-day availability SLO."
  value       = google_monitoring_slo.availability.name
}

output "sre_dashboard_id" {
  description = "Cloud Monitoring SRE Overview dashboard resource ID."
  value       = google_monitoring_dashboard.portfolio_sre.id
}
