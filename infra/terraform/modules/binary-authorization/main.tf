# ------------------------------------------------------------------------------
# Cloud KMS Asymmetric Signing Key for Binary Authorization Attestations
# ------------------------------------------------------------------------------
resource "google_kms_key_ring" "binauthz" {
  project  = var.project_id
  name     = "${var.name_prefix}-binauthz-ring"
  location = var.region
}

resource "google_kms_crypto_key" "attestor" {
  name     = "${var.name_prefix}-ci-attestor-key"
  key_ring = google_kms_key_ring.binauthz.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }

  labels = var.labels
}

data "google_kms_crypto_key_version" "attestor" {
  crypto_key = google_kms_crypto_key.attestor.id
}

# ------------------------------------------------------------------------------
# Container Analysis Note & Binary Authorization Attestor
# ------------------------------------------------------------------------------
resource "google_container_analysis_note" "attestor" {
  project = var.project_id
  name    = "${var.name_prefix}-ci-attestor-note"

  attestation_authority {
    hint {
      human_readable_name = "PortfolioOps GitHub Actions CI/CD Attestor"
    }
  }
}

resource "google_binary_authorization_attestor" "ci" {
  project     = var.project_id
  name        = "${var.name_prefix}-ci-attestor"
  description = "Verifies container images were built, scanned, and signed by PortfolioOps CI"

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor.name

    public_keys {
      id = data.google_kms_crypto_key_version.attestor.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.attestor.public_key[0].algorithm
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Enforced Cluster Admission Policy
# Blocks any unattested custom container image from running in GKE Autopilot.
# ------------------------------------------------------------------------------
resource "google_binary_authorization_policy" "policy" {
  project                       = var.project_id
  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.ci.name
    ]
  }

  # Narrow allowlist strictly for pinned third-party cluster infrastructure images
  # (lean Argo CD & Nginx Prometheus exporter). Custom images in Artifact Registry
  # are NEVER allowlisted and MUST carry a cryptographic attestation.
  dynamic "admission_whitelist_patterns" {
    for_each = toset(var.infrastructure_image_allowlist)
    content {
      name_pattern = admission_whitelist_patterns.value
    }
  }
}

# ------------------------------------------------------------------------------
# Least-Privilege IAM for GitHub CI Publisher SA to Create Attestations
# ------------------------------------------------------------------------------
resource "google_kms_crypto_key_iam_member" "ci_signer" {
  crypto_key_id = google_kms_crypto_key.attestor.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${var.ci_service_account_email}"
}

resource "google_container_analysis_note_iam_member" "ci_note_attacher" {
  project = var.project_id
  note    = google_container_analysis_note.attestor.name
  role    = "roles/containeranalysis.notes.attacher"
  member  = "serviceAccount:${var.ci_service_account_email}"
}

resource "google_binary_authorization_attestor_iam_member" "ci_attestor_viewer" {
  project  = var.project_id
  attestor = google_binary_authorization_attestor.ci.name
  role     = "roles/binaryauthorization.attestorsViewer"
  member   = "serviceAccount:${var.ci_service_account_email}"
}
