package handler

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/privacy"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/publisher"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/ratelimit"
)

type spyPublisher struct {
	mu     sync.Mutex
	events []publisher.VisitorEvent
}

func (s *spyPublisher) Publish(_ context.Context, e publisher.VisitorEvent) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.events = append(s.events, e)
	return nil
}

func (s *spyPublisher) Close() error { return nil }

func newTestHandler(burst int) (*Handler, *spyPublisher) {
	spy := &spyPublisher{}
	logger := slog.New(slog.NewJSONHandler(io.Discard, nil))
	h := New(spy, ratelimit.New(60, burst), privacy.NewSaltRotator(), logger, 2048, time.Second)
	return h, spy
}

func TestHealthz(t *testing.T) {
	h, _ := newTestHandler(5)
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK || strings.TrimSpace(rec.Body.String()) != "ok" {
		t.Fatalf("unexpected healthz response: %d %q", rec.Code, rec.Body.String())
	}
}

func TestIngestValidEvent(t *testing.T) {
	h, spy := newTestHandler(5)
	body := `{"event_type":"page_view","page_path":"/","referrer":"https://linkedin.com/in/bikramsarkar?trk=1"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/events", strings.NewReader(body))
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	req.Header.Set("X-Forwarded-For", "198.51.100.7, 10.0.0.1")

	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202 Accepted, got %d (%s)", rec.Code, rec.Body.String())
	}
	if len(spy.events) != 1 {
		t.Fatalf("expected 1 published event, got %d", len(spy.events))
	}
	ev := spy.events[0]
	if ev.ReferrerDomain != "linkedin.com" {
		t.Errorf("expected sanitized referrer linkedin.com, got %q", ev.ReferrerDomain)
	}
	if ev.DeviceCategory != "desktop" {
		t.Errorf("expected desktop device, got %q", ev.DeviceCategory)
	}
	if len(ev.SessionID) != 16 {
		t.Errorf("expected 16-char hashed session_id, got %q", ev.SessionID)
	}
}

func TestBotFilteredSilently(t *testing.T) {
	h, spy := newTestHandler(5)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/events", strings.NewReader(`{"event_type":"page_view","page_path":"/"}`))
	req.Header.Set("User-Agent", "GoogleHC/1.0")
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204 No Content for bot, got %d", rec.Code)
	}
	if len(spy.events) != 0 {
		t.Fatalf("expected 0 published events for bot, got %d", len(spy.events))
	}
}

func TestValidationAndLimits(t *testing.T) {
	h, _ := newTestHandler(1)
	routes := h.Routes()

	// Method not allowed
	rec := httptest.NewRecorder()
	routes.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/events", nil))
	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected 405, got %d", rec.Code)
	}

	// Oversized payload > 2048 bytes
	oversized := bytes.Repeat([]byte("a"), 3000)
	reqBig := httptest.NewRequest(http.MethodPost, "/api/v1/events", bytes.NewReader(oversized))
	reqBig.Header.Set("User-Agent", "Mozilla/5.0")
	reqBig.RemoteAddr = "198.51.100.11:1234"
	recBig := httptest.NewRecorder()
	routes.ServeHTTP(recBig, reqBig)
	if recBig.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("expected 413, got %d", recBig.Code)
	}

	// Invalid event_type
	reqBad := httptest.NewRequest(http.MethodPost, "/api/v1/events", strings.NewReader(`{"event_type":"sql_inject","page_path":"/"}`))
	reqBad.Header.Set("User-Agent", "Mozilla/5.0")
	reqBad.RemoteAddr = "198.51.100.12:1234"
	recBad := httptest.NewRecorder()
	routes.ServeHTTP(recBad, reqBad)
	if recBad.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", recBad.Code)
	}

	// Rate limit enforced on 2nd request from same IP (burst=1)
	reqRL := httptest.NewRequest(http.MethodPost, "/api/v1/events", strings.NewReader(`{"event_type":"page_view","page_path":"/"}`))
	reqRL.Header.Set("User-Agent", "Mozilla/5.0")
	reqRL.RemoteAddr = "198.51.100.12:1234"
	recRL := httptest.NewRecorder()
	routes.ServeHTTP(recRL, reqRL)
	if recRL.Code != http.StatusTooManyRequests {
		t.Errorf("expected 429 on 2nd request, got %d", recRL.Code)
	}
}
