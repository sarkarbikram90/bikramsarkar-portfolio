resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions Pool"
  description               = "OIDC identity pool for GitHub Actions CI/CD"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC Provider"
  description                        = "OIDC provider restricted strictly to ${var.github_repository}"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Restrict federation strictly to this repository (and optionally main branch)
  attribute_condition = var.restrict_to_main_branch ? (
    "assertion.repository == '${var.github_repository}' && assertion.ref == 'refs/heads/main'"
    ) : (
    "assertion.repository == '${var.github_repository}'"
  )

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Dedicated least-privilege CI publisher SA.
# Intentionally has NO GKE cluster access: Argo CD owns cluster reconciliation.
resource "google_service_account" "ci_publisher" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "PortfolioOps GitHub CI Image Publisher"
  description  = "Pushes signed container images to Artifact Registry from GitHub Actions"
}

resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.ci_publisher.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  project    = var.project_id
  location   = var.artifact_registry_location
  repository = var.artifact_registry_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci_publisher.email}"
}
