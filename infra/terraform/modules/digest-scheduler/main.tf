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
        env {
          name  = "DIGEST_WEBHOOK_URL"
          value = var.digest_webhook_url
        }
      }
    }
  }
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
