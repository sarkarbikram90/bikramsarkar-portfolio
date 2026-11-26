# PortfolioOps — Operational Chaos, Drift & Recovery Drills

Executable GameDay exercises demonstrating Staff-level operational maturity on GKE Autopilot.

---

## Drill 1: Unauthorized Cluster Drift Detection & Self-Healing

**Objective**: Prove that out-of-band manual changes are automatically reverted to the Git source of truth.

```bash
# 1. Introduce manual drift (scale down replicas imperatively)
kubectl scale deployment/portfolio -n portfolio --replicas=1

# 2. Observe Argo CD detect OutOfSync and self-heal back to 2 replicas
kubectl get deployment portfolio -n portfolio -w
kubectl get application portfolio -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
```

**Pass Criteria**: Replica count automatically returns to `2/2` within Argo CD's reconciliation interval (`<= 180s`) with zero manual intervention.

---

## Drill 2: Zero-Downtime Pod Eviction & Drain Verification

**Objective**: Verify that pod termination causes zero HTTP 5xx errors during active traffic (`PDB minAvailable: 1`, `preStop: sleep 5`, `topologySpreadConstraints`).

```bash
# Terminal 1: Continuous external availability probe
while true; do
  code=$(curl -s -o /dev/null -w '%{http_code}' https://bikramsarkar.space/healthz)
  echo "$(date -u +%H:%M:%S) HTTP $code"
  sleep 0.5
done

# Terminal 2: Delete one live replica
POD=$(kubectl get pods -n portfolio -l app.kubernetes.io/name=portfolio -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD" -n portfolio
```

**Pass Criteria**: Zero non-200 responses in Terminal 1 while the replacement pod starts and passes `/healthz` readiness checks.

---

## Drill 3: Faulty Release Gate & GitOps Rollback (MTTR Measurement)

**Objective**: Demonstrate safe rollout protection and repeatable Git-driven rollback.

1. Open a test PR referencing a nonexistent or broken image digest in `deploy/gitops/envs/prod/values-portfolio.yaml` (or trigger a simulated failure in a staging branch).
2. Observe `maxUnavailable: 0` keeping existing healthy pods serving traffic while the new ReplicaSet fails `startupProbe`/`readinessProbe` and triggers `[Critical] PortfolioOps Container Restart Loop`.
3. Execute GitOps rollback:
   ```bash
   git revert <BAD_COMMIT_SHA>
   git push origin main
   kubectl rollout status deployment/portfolio -n portfolio
   ```

**Pass Criteria**: Zero user-facing downtime during the failed rollout; full clean recovery within 5 minutes of `git revert`.

---

## Drill 4: Supply-Chain Signature & Vulnerability Gate Verification

**Objective**: Prove only scanned, signed images with attested SBOMs reach production.

```bash
IMAGE_REF="us-central1-docker.pkg.dev/<PROJECT_ID>/portfolio-images/portfolio@sha256:<DIGEST>"

# Verify Cosign keyless signature against this repository's release workflow
cosign verify \
  --certificate-identity-regexp="^https://github.com/sarkarbikram90/bikramsarkar-portfolio/.github/workflows/release.yaml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  "$IMAGE_REF"

# Verify attested SPDX SBOM
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity-regexp="^https://github.com/sarkarbikram90/bikramsarkar-portfolio/.github/workflows/release.yaml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  "$IMAGE_REF"
```

**Pass Criteria**: Both signature and SPDX SBOM attestation verify cleanly against Sigstore Rekor.

---

## Drill 5: Full Infrastructure Rebuild & Emergency DNS Fallback

**Objective**: Validate 100% IaC reproducibility and zero-downtime fallback.

- **Emergency fallback**: Repoint `bikramsarkar.space` DNS `A` records to GitHub Pages (root `index.html` + `CNAME` remain intact).
- **Full rebuild**: Run `terraform apply` in `infra/terraform/environments/prod` followed by `./deploy/gitops/bootstrap/install.sh` to recreate VPC, GKE Autopilot, Artifact Registry, Certificate Manager, WIF, Cloud Monitoring SLOs/alerts, Pub/Sub → BigQuery pipeline, and Argo CD workloads from scratch.
