resource "google_certificate_manager_dns_authorization" "portfolio" {
  project     = var.project_id
  name        = "${var.name_prefix}-dns-auth"
  description = "DNS authorization for ${var.domain}"
  domain      = var.domain
  labels      = var.labels
}

resource "google_certificate_manager_certificate" "portfolio" {
  project     = var.project_id
  name        = "${var.name_prefix}-cert"
  description = "Google-managed TLS certificate for ${var.domain}"
  scope       = "DEFAULT"
  labels      = var.labels

  managed {
    domains = [var.domain]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.portfolio.id
    ]
  }
}

resource "google_certificate_manager_certificate_map" "portfolio" {
  project     = var.project_id
  name        = var.certificate_map_name
  description = "Certificate map bound to GKE Gateway (${var.domain})"
  labels      = var.labels
}

resource "google_certificate_manager_certificate_map_entry" "portfolio" {
  project     = var.project_id
  name        = "${var.name_prefix}-cert-entry"
  description = "Hostname entry for ${var.domain}"
  map         = google_certificate_manager_certificate_map.portfolio.name
  hostname    = var.domain
  certificates = [
    google_certificate_manager_certificate.portfolio.id
  ]
  labels = var.labels
}
