locals {
  runbook_base_url = "https://github.com/${var.github_repository}/blob/main/docs/runbooks"

  notification_channel_ids = compact([
    try(google_monitoring_notification_channel.email[0].name, ""),
    try(google_monitoring_notification_channel.webhook[0].name, ""),
  ])
}

# ------------------------------------------------------------------------------
# Notification Channels (optional; wire email and/or webhook when ready)
# ------------------------------------------------------------------------------
resource "google_monitoring_notification_channel" "email" {
  count        = var.alert_email != "" ? 1 : 0
  project      = var.project_id
  display_name = "PortfolioOps SRE Email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_notification_channel" "webhook" {
  count        = var.alert_webhook_url != "" ? 1 : 0
  project      = var.project_id
  display_name = "PortfolioOps Incident Webhook"
  type         = "webhook_tokenauth"
  labels = {
    url = var.alert_webhook_url
  }
}

# ------------------------------------------------------------------------------
# External HTTPS Uptime Checks (Homepage + /healthz)
# ------------------------------------------------------------------------------
resource "google_monitoring_uptime_check_config" "homepage" {
  project      = var.project_id
  display_name = "PortfolioOps HTTPS Homepage (${var.domain})"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  content_matchers {
    content = "Bikram Sarkar"
    matcher = "CONTAINS_STRING"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain
    }
  }

  selected_regions = ["USA", "EUROPE", "ASIA_PACIFIC"]
}

resource "google_monitoring_uptime_check_config" "healthz" {
  project      = var.project_id
  display_name = "PortfolioOps HTTPS /healthz (${var.domain})"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/healthz"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  content_matchers {
    content = "ok"
    matcher = "CONTAINS_STRING"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain
    }
  }

  selected_regions = ["USA", "EUROPE", "ASIA_PACIFIC"]
}

# ------------------------------------------------------------------------------
# Custom Service & 99.9% Rolling 30-Day Availability SLO (43.2 min error budget)
# ------------------------------------------------------------------------------
resource "google_monitoring_custom_service" "portfolio" {
  project      = var.project_id
  service_id   = "portfolio-web"
  display_name = "PortfolioOps Web (${var.domain})"
}

resource "google_monitoring_slo" "availability" {
  project             = var.project_id
  service             = google_monitoring_custom_service.portfolio.service_id
  slo_id              = "external-availability-999"
  display_name        = "99.9% External Availability (30d rolling)"
  goal                = 0.999
  rolling_period_days = 30

  windows_based_sli {
    window_period = "300s"
    good_bad_metric_filter = join(" AND ", [
      "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\"",
      "resource.type=\"uptime_url\"",
      "metric.label.check_id=\"${google_monitoring_uptime_check_config.homepage.uptime_check_id}\""
    ])
  }
}

# ------------------------------------------------------------------------------
# Alert Policies (all linked to GitHub incident runbooks)
# ------------------------------------------------------------------------------

# 1. Critical: External Site Unavailable across >= 2 probe regions
resource "google_monitoring_alert_policy" "site_unavailable" {
  project      = var.project_id
  display_name = "[Critical] PortfolioOps Site Unavailable (${var.domain})"
  combiner     = "OR"
  severity     = "CRITICAL"

  conditions {
    display_name = "HTTPS homepage uptime check failing in >= 2 regions"
    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\"",
        "resource.type=\"uptime_url\"",
        "metric.label.check_id=\"${google_monitoring_uptime_check_config.homepage.uptime_check_id}\""
      ])
      duration        = "120s"
      comparison      = "COMPARISON_GT"
      threshold_value = 1

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.host"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = local.notification_channel_ids

  documentation {
    mime_type = "text/markdown"
    subject   = "PortfolioOps site ${var.domain} is unreachable"
    content   = <<-EOT
      External HTTPS checks for **https://${var.domain}** are failing from multiple regions.

      - **Runbook**: ${local.runbook_base_url}/site-unavailable.md
      - **SLO Policy**: https://github.com/${var.github_repository}/blob/main/docs/slo-policy.md
    EOT
  }
}

# 2. Critical: Multi-Window Fast SLO Error Budget Burn (14.4x over 1h AND 5m)
resource "google_monitoring_alert_policy" "slo_fast_burn" {
  project      = var.project_id
  display_name = "[Critical] PortfolioOps 99.9% SLO Fast Error Budget Burn"
  combiner     = "AND"
  severity     = "CRITICAL"

  conditions {
    display_name = "1h burn rate > 14.4x (2% monthly budget in 1h)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"60m\")"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
    }
  }

  conditions {
    display_name = "5m burn rate > 14.4x (confirms active incident)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"5m\")"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
    }
  }

  notification_channels = local.notification_channel_ids

  documentation {
    mime_type = "text/markdown"
    subject   = "99.9% SLO Fast Burn (>14.4x) on ${var.domain}"
    content   = <<-EOT
      The 30-day error budget (43.2 minutes) is burning >14.4x across both 1h and 5m windows.

      - **Runbook**: ${local.runbook_base_url}/slo-error-budget-burn.md
    EOT
  }
}

# 3. Warning: Multi-Window Slow SLO Error Budget Burn (6x over 6h AND 30m)
resource "google_monitoring_alert_policy" "slo_slow_burn" {
  project      = var.project_id
  display_name = "[Warning] PortfolioOps 99.9% SLO Slow Error Budget Burn"
  combiner     = "AND"
  severity     = "WARNING"

  conditions {
    display_name = "6h burn rate > 6x (5% monthly budget in 6h)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"360m\")"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 6.0
    }
  }

  conditions {
    display_name = "30m burn rate > 6x (confirms sustained burn)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"30m\")"
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 6.0
    }
  }

  notification_channels = local.notification_channel_ids

  documentation {
    mime_type = "text/markdown"
    subject   = "99.9% SLO Slow Burn (>6x) on ${var.domain}"
    content   = <<-EOT
      Sustained error budget burn (>6x over 6h and 30m windows) detected for **${var.domain}**.

      - **Runbook**: ${local.runbook_base_url}/slo-error-budget-burn.md
    EOT
  }
}

# 4. Critical: Pod CrashLoopBackOff / Repeated Container Restarts
resource "google_monitoring_alert_policy" "pod_restarts" {
  project      = var.project_id
  display_name = "[Critical] PortfolioOps Container Restart Loop (${var.k8s_namespace})"
  combiner     = "OR"
  severity     = "CRITICAL"

  conditions {
    display_name = "Container restart delta > 2 in 10m"
    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"kubernetes.io/container/restart_count\"",
        "resource.type=\"k8s_container\"",
        "resource.label.cluster_name=\"${var.cluster_name}\"",
        "resource.label.namespace_name=\"${var.k8s_namespace}\""
      ])
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2

      aggregations {
        alignment_period     = "600s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.pod_name", "resource.label.container_name"]
      }
    }
  }

  notification_channels = local.notification_channel_ids

  documentation {
    mime_type = "text/markdown"
    subject   = "Container restart loop in namespace ${var.k8s_namespace}"
    content   = <<-EOT
      A container in GKE cluster **${var.cluster_name}** (`${var.k8s_namespace}`) restarted more than twice in 10 minutes.

      - **Runbook**: ${local.runbook_base_url}/pod-crashloop-and-rollback.md
    EOT
  }
}

# 5. Critical: External Load Balancer HTTP 5xx Error Spike
resource "google_monitoring_alert_policy" "http_5xx_spike" {
  project      = var.project_id
  display_name = "[Critical] PortfolioOps Gateway HTTP 5xx Spike"
  combiner     = "OR"
  severity     = "CRITICAL"

  conditions {
    display_name = "HTTP 5xx responses > 5 in 5m"
    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"loadbalancing.googleapis.com/https/request_count\"",
        "resource.type=\"https_lb_rule\"",
        "metric.label.response_code_class=\"500\""
      ])
      duration        = "120s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = local.notification_channel_ids

  documentation {
    mime_type = "text/markdown"
    subject   = "HTTP 5xx spike on ${var.domain} Gateway"
    content   = <<-EOT
      External HTTPS Load Balancer returned more than 5 HTTP 5xx responses over a 5-minute window.

      - **Runbook**: ${local.runbook_base_url}/http-5xx-and-gateway.md
    EOT
  }
}

# 6. Warning: High p95 Latency on External Load Balancer
resource "google_monitoring_alert_policy" "high_latency" {
  project      = var.project_id
  display_name = "[Warning] PortfolioOps High p95 Latency (>500ms)"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "HTTPS LB total latency p95 > 500ms for 10m"
    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"loadbalancing.googleapis.com/https/total_latencies\"",
        "resource.type=\"https_lb_rule\""
      ])
      duration        = "600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 500

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  notification_channels = local.notification_channel_ids

  documentation {
    mime_type = "text/markdown"
    subject   = "High p95 latency (>500ms) on ${var.domain}"
    content   = <<-EOT
      External HTTPS p95 latency exceeded 500ms for 10 consecutive minutes.

      - **Runbook**: ${local.runbook_base_url}/http-5xx-and-gateway.md
    EOT
  }
}

# ------------------------------------------------------------------------------
# Cloud Monitoring SRE Overview Dashboard
# ------------------------------------------------------------------------------
resource "google_monitoring_dashboard" "portfolio_sre" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "PortfolioOps — SRE Overview (${var.domain})"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "External HTTPS Uptime (Homepage)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\" metric.label.check_id=\"${google_monitoring_uptime_check_config.homepage.uptime_check_id}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_FRACTION_TRUE"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Gateway Requests by Response Class"
            xyChart = {
              dataSets = [{
                plotType = "STACKED_BAR"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.response_code_class"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 0
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Gateway Total Latency (p95 ms)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/total_latencies\" resource.type=\"https_lb_rule\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MAX"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Container Restarts (${var.k8s_namespace})"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"kubernetes.io/container/restart_count\" resource.type=\"k8s_container\" resource.label.cluster_name=\"${var.cluster_name}\" resource.label.namespace_name=\"${var.k8s_namespace}\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.pod_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 0
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Nginx Active Connections (Managed Prometheus)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"prometheus.googleapis.com/nginx_connections_active/gauge\" resource.type=\"prometheus_target\" resource.label.namespace=\"${var.k8s_namespace}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Pod CPU Utilization (${var.k8s_namespace})"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" resource.label.cluster_name=\"${var.cluster_name}\" resource.label.namespace_name=\"${var.k8s_namespace}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.container_name"]
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}
