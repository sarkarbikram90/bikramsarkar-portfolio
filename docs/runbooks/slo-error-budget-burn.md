# Runbook: 99.9% SLO Error Budget Burn

- **Alerts**:
  - `[Critical] PortfolioOps 99.9% SLO Fast Error Budget Burn` (`>14.4x` over 1h AND 5m)
  - `[Warning] PortfolioOps 99.9% SLO Slow Error Budget Burn` (`>6.0x` over 6h AND 30m)
- **Monthly Budget**: `43.2 minutes` of downtime per rolling 30 days.

## 1. Confirm Active Outage vs Recovering Spike

1. Open **Cloud Monitoring → SLOs → PortfolioOps Web (`external-availability-999`)**.
2. Check whether the 5-minute burn rate is still elevated or trending back toward `0`.
3. Inspect recent GitOps deployments:
   ```bash
   git log -n 5 --oneline deploy/gitops/envs/prod/values-portfolio.yaml
   ```

## 2. Fast Rollback via GitOps (Preferred)

Never run ad-hoc `kubectl edit` (Argo CD `selfHeal: true` will revert manual edits). Always roll back through Git:

```bash
# Identify the last known-good promotion commit and revert the bad commit
git revert <BAD_PROMOTION_COMMIT_SHA>
git push origin main
```

Verify Argo CD reconciles the previous `@sha256` digest within 3 minutes:

```bash
kubectl get application portfolio -n argocd
kubectl rollout status deployment/portfolio -n portfolio
```

## 3. Enforce Error Budget Policy

Per [SLO Policy](../slo-policy.md):
- If remaining budget falls below **25%**, pause feature PRs and file a reliability issue.
- If budget reaches **0%**, complete a blameless postmortem before resuming normal deployments.
