# syntax=docker/dockerfile:1.7

FROM golang:1.27-alpine AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd/ ./cmd/
COPY internal/ ./internal/

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/analytics-api ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

LABEL org.opencontainers.image.title="PortfolioOps Analytics API" \
      org.opencontainers.image.description="Privacy-first OpenTelemetry-instrumented Go visitor analytics service" \
      org.opencontainers.image.source="https://github.com/sarkarbikram90/bikramsarkar-portfolio"

COPY --from=builder /out/analytics-api /analytics-api

EXPOSE 8080

# Distroless nonroot user (UID/GID 65532 > 10000)
USER 65532:65532

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/analytics-api", "-healthcheck"]

ENTRYPOINT ["/analytics-api"]
