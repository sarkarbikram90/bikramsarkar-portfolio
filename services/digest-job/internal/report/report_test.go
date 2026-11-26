package report

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDetectSpike(t *testing.T) {
	if DetectSpike(10, 2.0, 1.0) {
		t.Error("expected low-volume traffic (<25) not to trigger spike")
	}
	if DetectSpike(40, 20.0, 10.0) {
		t.Error("expected 40 views <= 20 + 3*10 not to trigger spike")
	}
	if !DetectSpike(60, 20.0, 10.0) {
		t.Error("expected 60 views > 20 + 3*10 to trigger spike")
	}
}

func TestFormatTextAndWebhook(t *testing.T) {
	var received map[string]string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := json.NewDecoder(r.Body).Decode(&received); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	s := Summary{
		WindowLabel:     "last 24h",
		PageViews:       120,
		UniqueSessions:  84,
		ResumeDownloads: 7,
		BaselineAvg:     22.5,
		BaselineStdDev:  5.0,
		IsSpike:         true,
		TopReferrers: []ReferrerCount{
			{Domain: "linkedin.com", Views: 65},
			{Domain: "github.com", Views: 30},
		},
	}

	if err := SendWebhook(context.Background(), srv.Client(), srv.URL, s); err != nil {
		t.Fatalf("SendWebhook failed: %v", err)
	}

	text := received["text"]
	if !strings.Contains(text, "[TRAFFIC SPIKE]") || !strings.Contains(text, "linkedin.com (65)") {
		t.Fatalf("unexpected formatted digest: %q", text)
	}
}
