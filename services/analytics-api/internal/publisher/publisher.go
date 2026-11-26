package publisher

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"cloud.google.com/go/pubsub"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

// VisitorEvent matches the BigQuery visitor_events table schema 1:1
// so Pub/Sub native BigQuery subscriptions stream messages without an ETL worker.
type VisitorEvent struct {
	EventID        string `json:"event_id"`
	EventType      string `json:"event_type"`
	Timestamp      string `json:"timestamp"`
	PagePath       string `json:"page_path"`
	ReferrerDomain string `json:"referrer_domain"`
	SessionID      string `json:"session_id"`
	DeviceCategory string `json:"device_category"`
	CountryHint    string `json:"country_hint,omitempty"`
}

// Publisher sends sanitized visitor events downstream.
type Publisher interface {
	Publish(ctx context.Context, event VisitorEvent) error
	Close() error
}

// PubSubPublisher publishes events to Google Cloud Pub/Sub with OpenTelemetry spans.
type PubSubPublisher struct {
	client *pubsub.Client
	topic  *pubsub.Topic
}

// NewPubSubPublisher initializes a Google Cloud Pub/Sub publisher for the given project & topic.
func NewPubSubPublisher(ctx context.Context, projectID, topicID string) (*PubSubPublisher, error) {
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("create pubsub client: %w", err)
	}
	topic := client.Topic(topicID)
	return &PubSubPublisher{client: client, topic: topic}, nil
}

// Publish serializes and publishes the VisitorEvent with OTel span tracing.
func (p *PubSubPublisher) Publish(ctx context.Context, event VisitorEvent) error {
	tracer := otel.Tracer("analytics-api/publisher")
	ctx, span := tracer.Start(ctx, "pubsub.publish")
	defer span.End()

	span.SetAttributes(
		attribute.String("messaging.system", "gcp_pubsub"),
		attribute.String("messaging.destination.name", p.topic.ID()),
		attribute.String("analytics.event_type", event.EventType),
	)

	payload, err := json.Marshal(event)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "marshal failed")
		return fmt.Errorf("marshal event: %w", err)
	}

	res := p.topic.Publish(ctx, &pubsub.Message{
		Data: payload,
		Attributes: map[string]string{
			"event_type": event.EventType,
		},
	})
	msgID, err := res.Get(ctx)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "publish failed")
		return fmt.Errorf("publish to pubsub: %w", err)
	}
	span.SetAttributes(attribute.String("messaging.message.id", msgID))
	return nil
}

// Close flushes pending Pub/Sub batches and releases network connections.
func (p *PubSubPublisher) Close() error {
	p.topic.Stop()
	return p.client.Close()
}

// NoopPublisher logs sanitized events for local development when GCP_PROJECT_ID is unset.
type NoopPublisher struct {
	logger *slog.Logger
}

// NewNoopPublisher returns a local no-op publisher.
func NewNoopPublisher(logger *slog.Logger) *NoopPublisher {
	return &NoopPublisher{logger: logger}
}

func (n *NoopPublisher) Publish(ctx context.Context, event VisitorEvent) error {
	n.logger.InfoContext(ctx, "noop publish visitor event",
		"event_id", event.EventID,
		"event_type", event.EventType,
		"page_path", event.PagePath,
		"referrer_domain", event.ReferrerDomain,
		"device_category", event.DeviceCategory,
		"timestamp", event.Timestamp,
	)
	return nil
}

func (n *NoopPublisher) Close() error {
	return nil
}

// FormatTimestamp returns RFC3339Nano UTC timestamp accepted by BigQuery TIMESTAMP columns.
func FormatTimestamp(t time.Time) string {
	return t.UTC().Format(time.RFC3339Nano)
}
