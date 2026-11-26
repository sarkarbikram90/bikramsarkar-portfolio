locals {
  pubsub_service_agent = "service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ------------------------------------------------------------------------------
# BigQuery Dataset & Partitioned Visitor Events Table
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "analytics" {
  project       = var.project_id
  dataset_id    = var.dataset_id
  friendly_name = "PortfolioOps Visitor Analytics"
  description   = "Privacy-first pseudonymous visitor events streamed natively from Pub/Sub"
  location      = var.bigquery_location
  labels        = var.labels
}

resource "google_bigquery_table" "visitor_events" {
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = var.table_id
  description         = "Daily partitioned visitor events (zero PII; 365-day retention)"
  deletion_protection = var.deletion_protection
  labels              = var.labels

  time_partitioning {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = 31536000000 # 365 days
  }

  clustering = ["event_type", "page_path"]

  schema = jsonencode([
    { name = "event_id", type = "STRING", mode = "REQUIRED", description = "Random 128-bit event identifier" },
    { name = "event_type", type = "STRING", mode = "REQUIRED", description = "page_view, resume_download, or outbound_click" },
    { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED", description = "UTC event ingestion timestamp" },
    { name = "page_path", type = "STRING", mode = "REQUIRED", description = "Requested site path" },
    { name = "referrer_domain", type = "STRING", mode = "NULLABLE", description = "Sanitized referrer hostname or direct" },
    { name = "session_id", type = "STRING", mode = "REQUIRED", description = "Ephemeral daily-salted pseudonymous hash" },
    { name = "device_category", type = "STRING", mode = "REQUIRED", description = "desktop, mobile, or tablet" },
    { name = "country_hint", type = "STRING", mode = "NULLABLE", description = "Optional coarse region header from Load Balancer" }
  ])
}

# ------------------------------------------------------------------------------
# Pub/Sub Topic, Dead-Letter Topic & Native BigQuery Subscription (Zero Pods!)
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "visitor_events" {
  project                    = var.project_id
  name                       = var.topic_id
  message_retention_duration = "86400s"
  labels                     = var.labels
}

resource "google_pubsub_topic" "visitor_events_dlq" {
  project                    = var.project_id
  name                       = "${var.topic_id}-dlq"
  message_retention_duration = "604800s"
  labels                     = var.labels
}

resource "google_pubsub_subscription" "visitor_events_dlq_pull" {
  project = var.project_id
  name    = "${var.topic_id}-dlq-sub"
  topic   = google_pubsub_topic.visitor_events_dlq.id
  labels  = var.labels

  message_retention_duration = "604800s"
  retain_acked_messages      = false
  ack_deadline_seconds       = 20
}

# Grant Google's managed Pub/Sub service agent write access to the BigQuery table & DLQ
resource "google_bigquery_table_iam_member" "pubsub_bq_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = google_bigquery_table.visitor_events.table_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_bigquery_table_iam_member" "pubsub_bq_metadata" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = google_bigquery_table.visitor_events.table_id
  role       = "roles/bigquery.metadataViewer"
  member     = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_pubsub_topic_iam_member" "pubsub_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.visitor_events_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_pubsub_subscription" "bigquery_sink" {
  project = var.project_id
  name    = "${var.topic_id}-bq-sink"
  topic   = google_pubsub_topic.visitor_events.id
  labels  = var.labels

  bigquery_config {
    table               = "${var.project_id}:${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.visitor_events.table_id}"
    use_table_schema    = true
    write_metadata      = false
    drop_unknown_fields = true
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.visitor_events_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [
    google_bigquery_table_iam_member.pubsub_bq_editor,
    google_bigquery_table_iam_member.pubsub_bq_metadata,
    google_pubsub_topic_iam_member.pubsub_dlq_publisher,
  ]
}

resource "google_pubsub_subscription_iam_member" "pubsub_dlq_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.bigquery_sink.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.pubsub_service_agent}"
}

# ------------------------------------------------------------------------------
# GKE Workload Identity Service Account for Go analytics-api
# ------------------------------------------------------------------------------
resource "google_service_account" "analytics_api" {
  project      = var.project_id
  account_id   = "analytics-api-sa"
  display_name = "PortfolioOps Analytics API Workload SA"
  description  = "Least-privilege SA for Go analytics-api publishing to Pub/Sub and emitting OTel telemetry"
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.analytics_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}

resource "google_pubsub_topic_iam_member" "analytics_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.visitor_events.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.analytics_api.email}"
}

resource "google_project_iam_member" "analytics_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.analytics_api.email}"
}

resource "google_project_iam_member" "analytics_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.analytics_api.email}"
}
