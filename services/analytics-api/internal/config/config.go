package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds runtime settings populated from environment variables.
type Config struct {
	Port                string
	GCPProjectID        string
	PubSubTopicID       string
	OTLPEndpoint        string
	OTLPInsecure        bool
	ServiceName         string
	ServiceVersion      string
	RateLimitPerMinute  int
	RateLimitBurst      int
	MaxBodyBytes        int64
	PublishTimeout      time.Duration
	ShutdownGracePeriod time.Duration
}

// Load reads Config from environment variables with production-safe defaults.
func Load() Config {
	return Config{
		Port:                getEnv("PORT", "8080"),
		GCPProjectID:        os.Getenv("GCP_PROJECT_ID"),
		PubSubTopicID:       getEnv("PUBSUB_TOPIC_ID", "portfolio-visitor-events"),
		OTLPEndpoint:        os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		OTLPInsecure:        getEnvBool("OTEL_EXPORTER_OTLP_INSECURE", true),
		ServiceName:         getEnv("OTEL_SERVICE_NAME", "analytics-api"),
		ServiceVersion:      getEnv("SERVICE_VERSION", "1.0.0"),
		RateLimitPerMinute:  getEnvInt("RATE_LIMIT_PER_MINUTE", 30),
		RateLimitBurst:      getEnvInt("RATE_LIMIT_BURST", 10),
		MaxBodyBytes:        int64(getEnvInt("MAX_BODY_BYTES", 2048)),
		PublishTimeout:      time.Duration(getEnvInt("PUBLISH_TIMEOUT_MS", 3000)) * time.Millisecond,
		ShutdownGracePeriod: 10 * time.Second,
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return fallback
}

func getEnvBool(key string, fallback bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return fallback
}
