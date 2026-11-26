package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/config"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/handler"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/privacy"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/publisher"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/ratelimit"
	"github.com/sarkarbikram90/bikramsarkar-portfolio/services/analytics-api/internal/telemetry"
)

func main() {
	healthcheck := flag.Bool("healthcheck", false, "run local /healthz probe and exit")
	flag.Parse()

	cfg := config.Load()
	if *healthcheck {
		os.Exit(runHealthcheck(cfg.Port))
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	otelShutdown, err := telemetry.Init(ctx, cfg.ServiceName, cfg.ServiceVersion, cfg.OTLPEndpoint, cfg.OTLPInsecure, logger)
	if err != nil {
		logger.Error("failed to initialize OpenTelemetry", "error", err)
		os.Exit(1)
	}

	var pub publisher.Publisher
	if cfg.GCPProjectID != "" {
		pub, err = publisher.NewPubSubPublisher(ctx, cfg.GCPProjectID, cfg.PubSubTopicID)
		if err != nil {
			logger.Error("failed to initialize Pub/Sub publisher", "error", err)
			os.Exit(1)
		}
		logger.Info("Pub/Sub publisher initialized", "project_id", cfg.GCPProjectID, "topic", cfg.PubSubTopicID)
	} else {
		pub = publisher.NewNoopPublisher(logger)
		logger.Warn("GCP_PROJECT_ID not set; using NoopPublisher")
	}

	h := handler.New(
		pub,
		ratelimit.New(cfg.RateLimitPerMinute, cfg.RateLimitBurst),
		privacy.NewSaltRotator(),
		logger,
		cfg.MaxBodyBytes,
		cfg.PublishTimeout,
	)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           otelhttp.NewHandler(h.Routes(), "analytics-api"),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		logger.Info("analytics-api listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("http server error", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	logger.Info("shutdown signal received; draining connections")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownGracePeriod)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("http server shutdown error", "error", err)
	}
	if err := pub.Close(); err != nil {
		logger.Error("publisher close error", "error", err)
	}
	if err := otelShutdown(shutdownCtx); err != nil {
		logger.Error("otel shutdown error", "error", err)
	}
}

func runHealthcheck(port string) int {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%s/healthz", port))
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
