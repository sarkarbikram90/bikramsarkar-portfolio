# PortfolioOps — Live Production Evidence Log

> Populate this directory immediately after `terraform apply` and DNS cutover. In 2026, live operational proof (traces, blocked admission logs, GameDay timings, and real billing data) is what separates a production platform from a static template.

## 1. Live Edge & TLS Verification
Record after DNS cutover:
- [ ] `curl -sI https://bikramsarkar.space/` → HTTP `200`, `Strict-Transport-Security`, `Content-Security-Policy`
- [ ] `curl -sI http://bikramsarkar.space/` → HTTP `301` → `https://bikramsarkar.space/`
- [ ] `gcloud certificate-manager certificates describe portfolio-cert` → `ACTIVE`
- [ ] Screenshot: `docs/evidence/gateway-and-argocd-healthy.png`

## 2. Supply-Chain Admission Proof (Binary Authorization + Cosign)
Prove that unsigned images are **actually blocked** by GKE Autopilot:

```bash
# Attempt to run an unattested image in the portfolio namespace (MUST be denied by Binary Authorization)
kubectl run unattested-test -n portfolio --image=us-central1-docker.pkg.dev/<PROJECT_ID>/portfolio-images/portfolio:unattested --restart=Never
```

- [ ] Capture the admission controller denial message (`Image ... denied by Binary Authorization default admission rule`).
- [ ] Capture `cosign verify` and `cosign verify-attestation --type spdxjson` output for the live production digest.

## 3. End-to-End Observability & GameDay Results

| Drill / Check | Date (UTC) | Observed Result | MTTR / Latency |
| --- | --- | --- | --- |
| Drill 1 — Argo CD Drift Self-Heal (`scale=1` → `2`) | _TBD_ | _Pass/Fail_ | _e.g. 42s_ |
| Drill 2 — Live Pod Eviction during `curl` loop | _TBD_ | _0 non-200s_ | _0ms downtime_ |
| Drill 3 — Faulty Promotion & `git revert` Rollback | _TBD_ | _Pass/Fail_ | _e.g. 2m 15s_ |
| Cloud Trace Waterfall (`Gateway → analytics-api → Pub/Sub`) | _TBD_ | _Screenshot attached_ | _e.g. 18ms p95_ |
| BigQuery `visitor_events` + Daily Digest Webhook | _TBD_ | _Delivered_ | _Scheduled 08:00 UTC_ |

## 4. Month-1 FinOps Actuals vs ADR-001 Estimate

| Component | ADR-001 Estimate | Actual Month-1 Spend | Notes |
| --- | --- | --- | --- |
| GKE Autopilot control plane | `$0` (free credit) | _TBD_ | |
| Global External ALB (Gateway) | `~$18.25` | _TBD_ | |
| Portfolio + Analytics API pods | `~$5–$12` | _TBD_ | |
| Tuned Lean Argo CD pods | `~$15–$25` | _TBD_ | |
| Cloud Run Job / Pub/Sub / BigQuery / KMS / OTel | `~$0–$2` | _TBD_ | |
| **Total** | **`~$38–$57/mo`** | **_TBD_** | |
