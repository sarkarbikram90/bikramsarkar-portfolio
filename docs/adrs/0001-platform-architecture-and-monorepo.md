# ADR-001: PortfolioOps Target Architecture, Cost Guardrails, and Single-Repo Layout

- **Status**: Accepted
- **Date**: 2026-11-25
- **Owner**: Bikram Sarkar

## Context

`https://bikramsarkar.space` is currently a static HTML portfolio served via GitHub Pages. The goal of **PortfolioOps** is to evolve this site into a production-grade Platform Engineering / SRE reference implementation on Google Cloud Platform (GCP) featuring:

- Hardened containerization and Kubernetes delivery on GKE Autopilot
- GitOps-driven reconciliation with immutable image digests
- Supply-chain security (WIF, vulnerability scanning, SBOM, image signing)
- First-class observability via Managed OpenTelemetry for GKE, SLOs, and alert-linked runbooks
- Privacy-conscious visitor analytics via a Go microservice, Pub/Sub, and BigQuery

At the same time, this is a personal engineering showcase, so monthly cloud spend must stay tightly controlled and every technology choice must solve a real requirement rather than add gratuitous operational overhead.

## Decisions

### 1. Region & Compute Platform: GKE Autopilot in `us-central1`
- **Choice**: Single GKE Autopilot cluster in `us-central1` (Iowa).
- **Rationale**:
  - Autopilot eliminates node-pool patching and scales billing directly to pod resource requests.
  - One Autopilot cluster's management fee (`$0.10/hr` = `$74.40/mo`) is covered by GCP's `$74.40/mo` free-tier GKE credit per billing account (assuming no other GKE cluster consumes it).
  - `us-central1` offers lower pod compute pricing than `asia-south1` and receives the earliest GKE feature rollouts (such as Managed OpenTelemetry for GKE).
- **Autopilot-Argo CD Drift Prevention**: Pod requests are explicitly sized to burstable Autopilot ratios (`50m` CPU / `64Mi` RAM = `1:1.28`, within the allowed `1:1`–`1:6.5` vCPU:GiB range) so Autopilot admission mutation does not trigger perpetual `OutOfSync` drift in Argo CD.

### 2. Single-Repo ("Monorepo") Layout with Clean Extraction Boundaries
- **Choice**: Keep static site assets, Docker/Nginx config, Helm charts, GitOps manifests, Terraform IaC, future Go analytics service, and docs inside `bikramsarkar-portfolio`.
- **Rationale**:
  - Keeping static files (`index.html`, `profile.png`, `CNAME`, `assets/`) at the repository root preserves GitHub Pages zero-downtime serving until DNS cutover to GKE.
  - Reduces cross-repo ceremony during initial build-out while maintaining strict directory boundaries (`deploy/charts/`, `deploy/gitops/`, `infra/terraform/`, `services/`).
- **Loop Prevention Rule**:
  - Application CI/release workflows use path filters (`paths-ignore: ['deploy/gitops/**', 'infra/**', 'docs/**']`).
  - Release automation updates image `@sha256` digests only inside `deploy/gitops/envs/prod/values.yaml`.
  - Argo CD watches only `deploy/gitops/` and `deploy/charts/`.
- **Exit Strategy**: Extracting `deploy/gitops/` or `infra/terraform/` into separate repositories later requires moving the folder and updating one Argo CD `repoURL` — zero Helm chart or application changes.

### 3. Hardened Non-Root Nginx Container
- **Choice**: Base on `nginxinc/nginx-unprivileged:1.31-alpine-slim` running as UID/GID `10101` (`> 10000` to avoid host UID overlap), overriding `ENTRYPOINT ["nginx"]` so `/docker-entrypoint.sh` never attempts filesystem writes under `readOnlyRootFilesystem: true`.
- **Rationale**:
  - All Nginx temp paths and PID files are directed to `/tmp` (`emptyDir` capped at `16Mi`).
  - Structured JSON access logs write to `/dev/stdout` matching Google Cloud Logging `httpRequest` fields.
  - Security headers (HSTS, CSP, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`) are injected via an included snippet so asset `location` blocks never silently drop parent headers.
  - Localhost-only `127.0.0.1:8081/stub_status` prepares for optional Prometheus scraping in Phase 4 without exposing metrics externally.

### 4. External Traffic: GKE Gateway API + Certificate Manager + `HealthCheckPolicy`
- **Choice**: `gke-l7-global-external-managed` Gateway with Certificate Manager (`networking.gke.io/certmap`), HTTP-to-HTTPS `301` `HTTPRoute` redirect, and an explicit `networking.gke.io/v1` `HealthCheckPolicy` targeting `/healthz`.
- **Rationale**:
  - GKE Ingress is in maintenance mode and lacks native Certificate Manager integration.
  - HTTP + HTTPS listeners share the flat `$0.025/hr` (~`$18.25/mo`) first-5 forwarding-rules tier.
  - Public Google-managed certificates in Certificate Manager are free.

### 5. GitOps Controller: Argo CD Tuned Lean
- **Choice**: Argo CD in a stripped-down configuration (disabling Dex, Notifications, and ApplicationSet controllers initially) with Autopilot-compliant burstable requests.
- **Rationale**:
  - Preserves Argo CD's visual reconciliation UI for demos/interviews while cutting default Argo CD Autopilot compute overhead from `~$40–$50/mo` down to `~$15–$25/mo`.
  - Alternative considered: Flux CD (`~$5–$10/mo` footprint); kept as a documented fallback if further cost reduction is needed.

### 6. Data & Analytics Architecture (No PostgreSQL Initially)
- **Choice**: Defer Cloud SQL PostgreSQL; use Git/GCS for static media and a future Go visitor API (`services/analytics-api/`) routed on `/api/v1/events` (same origin) → Pub/Sub → **native Pub/Sub BigQuery Subscription** → partitioned BigQuery table + **Cloud Scheduler / Cloud Run Job** for daily visitor digests.
- **Rationale**:
  - Avoids paying for and administering an idle relational database with no transactional schema.
  - Native Pub/Sub-to-BigQuery subscriptions eliminate an always-on consumer pod in GKE.
  - Same-origin routing eliminates CORS complexity and enables browser-to-backend trace propagation (`traceparent`).

## Cost Guardrails

| Component | Target Monthly Spend |
| --- | --- |
| GKE Autopilot control plane (1 cluster) | `$0` (covered by `$74.40` free credit) |
| Global External ALB (HTTP + HTTPS) | `~$18.25` |
| Certificate Manager (public TLS) | `$0` |
| Portfolio + Go API pods (2 replicas each) | `~$5–$12` |
| Tuned lean Argo CD | `~$15–$25` |
| AR, Pub/Sub, BigQuery, Managed OTel | `~$0–$2` (within free tiers; metric allowlisting) |
| **Target Total** | **`~$38–$57/mo`** |

- Cloud Armor Standard (`~$8+/mo`) is deferred until the public Go API endpoint is deployed (in-app rate limiting comes first).
- GCP Billing Budget alerts (`50%`, `80%`, `100%`) will be provisioned via Terraform in Phase 1/2 before cluster creation.

## Consequences

- **Positive**: Clean security posture, zero Argo CD/Autopilot resource drift, zero-downtime GitHub Pages fallback during build-out, realistic cost ceiling.
- **Trade-offs**: Single-repo CI requires strict path-filtering discipline; running lean Argo CD trades away Dex SSO and ApplicationSet features until explicitly needed.
