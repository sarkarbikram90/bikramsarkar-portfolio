# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd/ ./cmd/
COPY internal/ ./internal/

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/digest-job ./cmd/digest

FROM gcr.io/distroless/static-debian12:nonroot

LABEL org.opencontainers.image.title="PortfolioOps Daily Visitor Digest Job" \
      org.opencontainers.image.description="Serverless Cloud Run Job querying BigQuery visitor analytics and delivering daily digests" \
      org.opencontainers.image.source="https://github.com/sarkarbikram90/bikramsarkar-portfolio"

COPY --from=builder /out/digest-job /digest-job

USER 65532:65532

# Batch Cloud Run Job (runs to completion; no listening HTTP daemon)
HEALTHCHECK NONE

ENTRYPOINT ["/digest-job"]
