package report

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
)

// ReferrerCount represents traffic volume from a sanitized referrer hostname.
type ReferrerCount struct {
	Domain string `json:"domain"`
	Views  int64  `json:"views"`
}

// Summary aggregates 24-hour privacy-first visitor metrics alongside a 7-day baseline.
type Summary struct {
	WindowLabel     string          `json:"window_label"`
	PageViews       int64           `json:"page_views"`
	UniqueSessions  int64           `json:"unique_sessions"`
	ResumeDownloads int64           `json:"resume_downloads"`
	BaselineAvg     float64         `json:"baseline_avg"`
	BaselineStdDev  float64         `json:"baseline_stddev"`
	IsSpike         bool            `json:"is_spike"`
	TopReferrers    []ReferrerCount `json:"top_referrers"`
}

// DetectSpike flags traffic exceeding 3 standard deviations above the 7-day daily average
// with a minimum floor (25 views) to prevent noise on low-traffic personal sites.
func DetectSpike(pageViews int64, baselineAvg, baselineStdDev float64) bool {
	if pageViews < 25 || baselineAvg <= 0 {
		return false
	}
	return float64(pageViews) > (baselineAvg + 3.0*baselineStdDev)
}

// FormatText builds a concise Google Chat / Slack-compatible digest message.
func FormatText(s Summary) string {
	var b strings.Builder
	if s.IsSpike {
		b.WriteString("[TRAFFIC SPIKE] ")
	}
	fmt.Fprintf(&b, "PortfolioOps Visitor Digest (%s)\n", s.WindowLabel)
	fmt.Fprintf(&b, "• Page views: %d (7d avg: %.1f)\n", s.PageViews, s.BaselineAvg)
	fmt.Fprintf(&b, "• Approx. unique visitors: %d\n", s.UniqueSessions)
	fmt.Fprintf(&b, "• Resume downloads: %d\n", s.ResumeDownloads)

	if len(s.TopReferrers) > 0 {
		b.WriteString("• Top referrers: ")
		parts := make([]string, 0, len(s.TopReferrers))
		for _, r := range s.TopReferrers {
			parts = append(parts, fmt.Sprintf("%s (%d)", r.Domain, r.Views))
		}
		b.WriteString(strings.Join(parts, ", "))
		b.WriteString("\n")
	}
	return b.String()
}

// SendWebhook posts a JSON `{"text": "..."}` payload compatible with Google Chat and Slack incoming webhooks.
func SendWebhook(ctx context.Context, client *http.Client, webhookURL string, s Summary) error {
	body, err := json.Marshal(map[string]string{
		"text": FormatText(s),
	})
	if err != nil {
		return fmt.Errorf("marshal webhook payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, webhookURL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build webhook request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("post webhook: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("webhook returned HTTP %d", resp.StatusCode)
	}
	return nil
}
