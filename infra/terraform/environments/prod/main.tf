locals {
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "billingbudgets.googleapis.com",
    "certificatemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "telemetry.googleapis.com",
  ])

  common_labels = {
    managed-by  = "terraform"
    project     = "portfolio-ops"
    environment = "prod"
  }
}

resource "google_project_service" "required" {
  for_each           = local.required_apis
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "current" {
  project_id = var.project_id
  depends_on = [google_project_service.required]
}

module "networking" {
  source = "../../modules/networking"

  project_id             = var.project_id
  region                 = var.region
  name_prefix            = "portfolio"
  gateway_static_ip_name = "portfolio-ip"

  depends_on = [google_project_service.required]
}

module "gke_autopilot" {
  source = "../../modules/gke-autopilot"

  project_id                = var.project_id
  region                    = var.region
  cluster_name              = var.cluster_name
  vpc_id                    = module.networking.vpc_id
  subnet_id                 = module.networking.subnet_id
  pods_range_name           = module.networking.pods_range_name
  services_range_name       = module.networking.services_range_name
  enable_private_endpoint   = var.enable_private_endpoint
  master_authorized_cidrs   = var.master_authorized_cidrs
  release_channel           = var.release_channel
  binary_authorization_mode = var.binary_authorization_mode
  deletion_protection       = var.deletion_protection
  labels                    = local.common_labels

  depends_on = [google_project_service.required]
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id        = var.project_id
  region            = var.region
  repository_id     = var.artifact_registry_repository_id
  keep_recent_count = 10
  labels            = local.common_labels

  depends_on = [google_project_service.required]
}

module "certificate_manager" {
  source = "../../modules/certificate-manager"

  project_id           = var.project_id
  domain               = var.domain
  name_prefix          = "portfolio"
  certificate_map_name = "portfolio-cert-map"
  labels               = local.common_labels

  depends_on = [google_project_service.required]
}

module "workload_identity_github" {
  source = "../../modules/workload-identity-github"

  project_id                      = var.project_id
  github_repository               = var.github_repository
  restrict_to_main_branch         = true
  artifact_registry_location      = var.region
  artifact_registry_repository_id = module.artifact_registry.repository_id

  depends_on = [google_project_service.required]
}

module "billing_budget" {
  source = "../../modules/billing-budget"

  billing_account_id    = var.billing_account_id
  project_number        = data.google_project.current.number
  name_prefix           = "portfolio-ops"
  monthly_budget_amount = var.monthly_budget_usd
  currency_code         = "USD"

  depends_on = [google_project_service.required]
}

module "observability" {
  source = "../../modules/observability"

  project_id        = var.project_id
  domain            = var.domain
  cluster_name      = module.gke_autopilot.cluster_name
  k8s_namespace     = "portfolio"
  github_repository = var.github_repository
  alert_email       = var.alert_email
  alert_webhook_url = var.alert_webhook_url

  depends_on = [google_project_service.required]
}

module "analytics_pipeline" {
  source = "../../modules/analytics-pipeline"

  project_id          = var.project_id
  project_number      = data.google_project.current.number
  k8s_namespace       = "portfolio"
  k8s_service_account = "analytics-api"
  deletion_protection = var.deletion_protection
  labels              = local.common_labels

  depends_on = [google_project_service.required]
}
