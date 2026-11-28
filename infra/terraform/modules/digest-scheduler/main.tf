# ------------------------------------------------------------------------------
# Least-Privilege Service Accounts for Serverless Daily Visitor Digest
# ------------------------------------------------------------------------------
resource "google_service_account" "digest_job" {
  project      = var.project_id
  account_id   = "analytics-digest-job-sa"
  display_name = "PortfolioOps BigQuery Daily Digest Job SA"
  description  = "Queries portfolio_analytics.visitor_events and posts daily visitor summaries"
}

resource "google_project_iam_member" "digest_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.digest_job.email}"
}

resource "google_bigquery_table_iam_member" "digest_bq_viewer" {
  project    = var.project_id
  dataset_id = var.bigquery_dataset_id
  table_id   = var.bigquery_table_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.digest_job.email}"
}

resource "google_service_account" "scheduler_invoker" {
  project      = var.project_id
  account_id   = "digest-scheduler-sa"
  display_name = "PortfolioOps Cloud Scheduler Invoker SA"
  description  = "Invokes the portfolio-daily-digest Cloud Run Job via OAuth"
}

# ------------------------------------------------------------------------------
# Secret Manager Shell for Webhook URL (zero plaintext in tfvars, state, or specs)
# Populate out-of-band with:
#   printf '%s' '<WEBHOOK_URL>' | gcloud secrets versions add portfolio-digest-webhook-url --data-file=-
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret" "digest_webhook" {
  project   = var.project_id
  secret_id = var.webhook_secret_id
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "digest_secret_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.digest_webhook.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.digest_job.email}"
}

# ------------------------------------------------------------------------------
# Cloud Run v2 Job & Daily Cloud Scheduler Trigger (zero always-on GKE pods)
# Created once `digest_image` is populated after the first CI image publish.
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "daily_digest" {
  count               = var.digest_image != "" ? 1 : 0
  project             = var.project_id
  name                = "portfolio-daily-digest"
  location            = var.region
  deletion_protection = false
  labels              = var.labels

  template {
    task_count = 1
    template {
      service_account = google_service_account.digest_job.email
      timeout         = "120s"
      max_retries     = 1

      containers {
        image = var.digest_image

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "BQ_DATASET_ID"
          value = var.bigquery_dataset_id
        }
        env {
          name  = "BQ_TABLE_ID"
          value = var.bigquery_table_id
        }

        dynamic "env" {
          for_each = var.enable_webhook_secret ? [1] : []
          content {
            name = "DIGEST_WEBHOOK_URL"
            value_source {
              secret_key_ref {
                secret  = google_secret_manager_secret.digest_webhook.secret_id
                version = var.webhook_secret_version
              }
            }
          }
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.digest_secret_accessor]
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_run_invoker" {
  count    = var.digest_image != "" ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.daily_digest[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_invoker.email}"
}

resource "google_cloud_scheduler_job" "daily_digest" {
  count            = var.digest_image != "" ? 1 : 0
  project          = var.project_id
  region           = var.region
  name             = "portfolio-daily-digest-trigger"
  description      = "Triggers daily visitor digest & traffic anomaly summary at 08:00 UTC"
  schedule         = var.schedule_cron
  time_zone        = "UTC"
  attempt_deadline = "180s"

  retry_config {
    retry_count = 2
  }

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.daily_digest[0].name}:run"
    body        = base64encode("{}")

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.scheduler_invoker.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_cloud_run_v2_job_iam_member.scheduler_run_invoker]
}
