package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"

	"cloud.google.com/go/bigquery"
	"google.golang.org/api/iterator"

	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/digest-job/internal/report"
)

type summaryRow struct {
	PageViews       int64               `bigquery:"page_views"`
	UniqueSessions  int64               `bigquery:"unique_sessions"`
	ResumeDownloads int64               `bigquery:"resume_downloads"`
	BaselineAvg     bigquery.NullFloat64 `bigquery:"baseline_avg"`
	BaselineStdDev  bigquery.NullFloat64 `bigquery:"baseline_stddev"`
}

type referrerRow struct {
	Domain string `bigquery:"referrer_domain"`
	Views  int64  `bigquery:"views"`
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	projectID := os.Getenv("GCP_PROJECT_ID")
	datasetID := getEnv("BQ_DATASET_ID", "portfolio_analytics")
	tableID := getEnv("BQ_TABLE_ID", "visitor_events")
	webhookURL := os.Getenv("DIGEST_WEBHOOK_URL")

	if projectID == "" {
		logger.Error("GCP_PROJECT_ID must be set")
		os.Exit(1)
	}

	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		logger.Error("failed to create BigQuery client", "error", err)
		os.Exit(1)
	}
	defer client.Close()

	tableFQN := fmt.Sprintf("`%s.%s.%s`", projectID, datasetID, tableID)

	sum, err := querySummary(ctx, client, tableFQN)
	if err != nil {
		logger.Error("failed to query daily summary", "error", err)
		os.Exit(1)
	}

	refs, err := queryTopReferrers(ctx, client, tableFQN)
	if err != nil {
		logger.Error("failed to query top referrers", "error", err)
		os.Exit(1)
	}
	sum.TopReferrers = refs

	logger.Info("daily visitor digest computed",
		"page_views", sum.PageViews,
		"unique_sessions", sum.UniqueSessions,
		"resume_downloads", sum.ResumeDownloads,
		"baseline_avg", sum.BaselineAvg,
		"is_spike", sum.IsSpike,
	)

	if webhookURL == "" {
		logger.Info("DIGEST_WEBHOOK_URL unset; printed digest to Cloud Logging only")
		return
	}

	httpClient := &http.Client{Timeout: 10 * time.Second}
	if err := report.SendWebhook(ctx, httpClient, webhookURL, sum); err != nil {
		logger.Error("failed to deliver digest webhook", "error", err)
		os.Exit(1)
	}
	logger.Info("daily visitor digest delivered to webhook")
}

func querySummary(ctx context.Context, client *bigquery.Client, tableFQN string) (report.Summary, error) {
	q := client.Query(fmt.Sprintf(`
WITH last_24h AS (
  SELECT
    COUNTIF(event_type = 'page_view') AS page_views,
    COUNT(DISTINCT session_id) AS unique_sessions,
    COUNTIF(event_type = 'resume_download') AS resume_downloads
  FROM %s
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
),
daily_baseline AS (
  SELECT
    DATE(timestamp) AS d,
    COUNTIF(event_type = 'page_view') AS daily_views
  FROM %s
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 8 DAY)
    AND timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  GROUP BY d
)
SELECT
  l.page_views,
  l.unique_sessions,
  l.resume_downloads,
  (SELECT AVG(daily_views) FROM daily_baseline) AS baseline_avg,
  (SELECT STDDEV_POP(daily_views) FROM daily_baseline) AS baseline_stddev
FROM last_24h l
`, tableFQN, tableFQN))

	it, err := q.Read(ctx)
	if err != nil {
		return report.Summary{}, err
	}

	var row summaryRow
	if err := it.Next(&row); err != nil && !errors.Is(err, iterator.Done) {
		return report.Summary{}, err
	}

	avg := 0.0
	if row.BaselineAvg.Valid {
		avg = row.BaselineAvg.Float64
	}
	std := 0.0
	if row.BaselineStdDev.Valid {
		std = row.BaselineStdDev.Float64
	}

	return report.Summary{
		WindowLabel:     "last 24h",
		PageViews:       row.PageViews,
		UniqueSessions:  row.UniqueSessions,
		ResumeDownloads: row.ResumeDownloads,
		BaselineAvg:     avg,
		BaselineStdDev:  std,
		IsSpike:         report.DetectSpike(row.PageViews, avg, std),
	}, nil
}

func queryTopReferrers(ctx context.Context, client *bigquery.Client, tableFQN string) ([]report.ReferrerCount, error) {
	q := client.Query(fmt.Sprintf(`
SELECT
  COALESCE(referrer_domain, 'direct') AS referrer_domain,
  COUNT(*) AS views
FROM %s
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND event_type = 'page_view'
GROUP BY referrer_domain
ORDER BY views DESC
LIMIT 5
`, tableFQN))

	it, err := q.Read(ctx)
	if err != nil {
		return nil, err
	}

	var out []report.ReferrerCount
	for {
		var r referrerRow
		err := it.Next(&r)
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, err
		}
		out = append(out, report.ReferrerCount{Domain: r.Domain, Views: r.Views})
	}
	return out, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
