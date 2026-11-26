package handler

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"

	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/privacy"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/publisher"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/ratelimit"
)

var allowedEventTypes = map[string]bool{
	"page_view":       true,
	"resume_download": true,
	"outbound_click":  true,
}

type ingestRequest struct {
	EventType string `json:"event_type"`
	PagePath  string `json:"page_path"`
	Referrer  string `json:"referrer,omitempty"`
}

// Handler serves the visitor analytics ingestion API and Kubernetes health probes.
type Handler struct {
	pub            publisher.Publisher
	limiter        *ratelimit.Limiter
	rotator        *privacy.SaltRotator
	logger         *slog.Logger
	maxBodyBytes   int64
	publishTimeout time.Duration

	eventsReceived  metric.Int64Counter
	eventsPublished metric.Int64Counter
	eventsRejected  metric.Int64Counter
	publishDuration metric.Float64Histogram
}

// New constructs a Handler wired with OTel metrics, privacy hashing, and rate limiting.
func New(
	pub publisher.Publisher,
	limiter *ratelimit.Limiter,
	rotator *privacy.SaltRotator,
	logger *slog.Logger,
	maxBodyBytes int64,
	publishTimeout time.Duration,
) *Handler {
	meter := otel.Meter("analytics-api/handler")
	received, _ := meter.Int64Counter("analytics.events.received", metric.WithDescription("Total incoming analytics events"))
	published, _ := meter.Int64Counter("analytics.events.published", metric.WithDescription("Events published to Pub/Sub"))
	rejected, _ := meter.Int64Counter("analytics.events.rejected", metric.WithDescription("Events rejected due to validation, bot filter, or rate limit"))
	duration, _ := meter.Float64Histogram("analytics.publish.duration_ms", metric.WithUnit("ms"), metric.WithDescription("Pub/Sub publish latency"))

	return &Handler{
		pub:             pub,
		limiter:         limiter,
		rotator:         rotator,
		logger:          logger,
		maxBodyBytes:    maxBodyBytes,
		publishTimeout:  publishTimeout,
		eventsReceived:  received,
		eventsPublished: published,
		eventsRejected:  rejected,
		publishDuration: duration,
	}
}

// Routes registers all HTTP endpoints on a ServeMux.
func (h *Handler) Routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", h.handleHealth)
	mux.HandleFunc("/readyz", h.handleHealth)
	mux.HandleFunc("/api/v1/events", h.handleIngestEvent)
	return mux
}

func (h *Handler) handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
}

func (h *Handler) handleIngestEvent(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	h.eventsReceived.Add(ctx, 1)

	ua := r.UserAgent()
	if privacy.IsBot(ua) {
		h.eventsRejected.Add(ctx, 1, metric.WithAttributes(attribute.String("reason", "bot")))
		w.WriteHeader(http.StatusNoContent)
		return
	}

	clientIP := privacy.ClientIP(r)
	if !h.limiter.Allow(clientIP) {
		h.eventsRejected.Add(ctx, 1, metric.WithAttributes(attribute.String("reason", "rate_limited")))
		http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, h.maxBodyBytes)
	rawBody, err := io.ReadAll(r.Body)
	if err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			h.eventsRejected.Add(ctx, 1, metric.WithAttributes(attribute.String("reason", "payload_too_large")))
			http.Error(w, "payload too large", http.StatusRequestEntityTooLarge)
			return
		}
		h.eventsRejected.Add(ctx, 1, metric.WithAttributes(attribute.String("reason", "read_error")))
		http.Error(w, "failed to read request body", http.StatusBadRequest)
		return
	}

	dec := json.NewDecoder(bytes.NewReader(rawBody))
	dec.DisallowUnknownFields()

	var req ingestRequest
	if err := dec.Decode(&req); err != nil {
		h.eventsRejected.Add(ctx, 1, metric.WithAttributes(attribute.String("reason", "invalid_json")))
		http.Error(w, "invalid json payload", http.StatusBadRequest)
		return
	}

	if err := validateRequest(req); err != nil {
		h.eventsRejected.Add(ctx, 1, metric.WithAttributes(attribute.String("reason", "validation_failed")))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	referrer := req.Referrer
	if referrer == "" {
		referrer = r.Referer()
	}

	event := publisher.VisitorEvent{
		EventID:        newEventID(),
		EventType:      req.EventType,
		Timestamp:      publisher.FormatTimestamp(time.Now()),
		PagePath:       req.PagePath,
		ReferrerDomain: privacy.ReferrerDomain(referrer),
		SessionID:      h.rotator.SessionID(clientIP, ua),
		DeviceCategory: privacy.ClassifyDevice(ua),
		// Optional region hint injected by Google Cloud Load Balancer custom header if configured
		CountryHint: strings.ToUpper(strings.TrimSpace(r.Header.Get("X-Client-Region"))),
	}

	pubCtx, cancel := context.WithTimeout(ctx, h.publishTimeout)
	defer cancel()

	start := time.Now()
	if err := h.pub.Publish(pubCtx, event); err != nil {
		h.eventsRejected.Add(ctx, 1, metric.WithAttributes(attribute.String("reason", "publish_error")))
		h.logWithTrace(ctx, slog.LevelError, "failed to publish visitor event", "error", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	elapsedMs := float64(time.Since(start).Microseconds()) / 1000.0
	h.publishDuration.Record(ctx, elapsedMs)
	h.eventsPublished.Add(ctx, 1, metric.WithAttributes(attribute.String("event_type", event.EventType)))

	w.WriteHeader(http.StatusAccepted)
}

func validateRequest(req ingestRequest) error {
	if !allowedEventTypes[req.EventType] {
		return errors.New("unsupported event_type")
	}
	if !strings.HasPrefix(req.PagePath, "/") || len(req.PagePath) > 256 {
		return errors.New("page_path must start with '/' and be <= 256 chars")
	}
	if len(req.Referrer) > 512 {
		return errors.New("referrer must be <= 512 chars")
	}
	return nil
}

func newEventID() string {
	buf := make([]byte, 16)
	_, _ = rand.Read(buf)
	return hex.EncodeToString(buf)
}

func (h *Handler) logWithTrace(ctx context.Context, level slog.Level, msg string, attrs ...any) {
	sc := trace.SpanContextFromContext(ctx)
	if sc.IsValid() {
		attrs = append(attrs, "trace_id", sc.TraceID().String(), "span_id", sc.SpanID().String())
	}
	h.logger.Log(ctx, level, msg, attrs...)
}
