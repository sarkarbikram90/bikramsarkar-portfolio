# PortfolioOps — SLO & Error Budget Policy

## Service Level Objectives (SLOs)

| Service | SLI | SLO Target | Evaluation Window | Error Budget |
| --- | --- | --- | --- | --- |
| **External Availability** (`bikramsarkar.space`) | Fraction of 5-minute windows where external HTTPS uptime checks pass (`monitoring.googleapis.com/uptime_check/check_passed`) | **99.9%** | 30-day rolling | **43.2 minutes** |
| **HTTP Success Ratio** (Gateway) | Non-5xx HTTP responses / total requests | **99.9%** | 30-day rolling | 0.1% failed requests |
| **HTTP Server Latency** (Gateway) | External HTTPS p95 total latency | **< 500 ms** | 10-minute sustained window | Alerted on breach |
| **GitOps Reconciliation** | Time from promotion PR merge to healthy Argo CD sync | **< 5 minutes** | Per release | Manual review if exceeded |

## Multi-Window Multi-Burn-Rate Alerting

Following the *Google SRE Workbook* (Chapter 5), availability alerts use dual lookback windows (`AND` combiner) to page quickly on real outages without false-paging on transient network blips:

| Alert | Severity | Long Window | Short Window | Budget Consumed | Action |
| --- | --- | --- | --- | --- | --- |
| **Fast Burn** | Critical | `60m` > `14.4x` | `5m` > `14.4x` | 2% in 1h | Immediate triage & rollback ([runbook](runbooks/slo-error-budget-burn.md)) |
| **Slow Burn** | Warning | `6h` > `6.0x` | `30m` > `6.0x` | 5% in 6h | Investigate same day, halt non-critical deploys |

## Error Budget Governance Policy

- **Remaining budget > 25%**: Normal release velocity (GitOps promotion PRs merged after CI passes).
- **Remaining budget 0%–25%**: Freeze non-reliability feature changes; prioritize hardening, probe tuning, or root-cause fixes.
- **Budget exhausted (0%)**: Freeze all feature changes until a postmortem is recorded and the 30-day rolling window recovers above 25% (exception: P0 security patches and reliability fixes).

## DORA Metrics Tracked

- **Deployment Frequency**: Count of merged `gitops/promote-*` PRs per week.
- **Lead Time for Changes**: Time from `main` commit to Argo CD `Healthy/Synced`.
- **Change Failure Rate**: Percentage of promotions requiring a rollback or hotfix.
- **Mean Time to Restore (MTTR)**: Time from `[Critical]` alert open to uptime recovery.
