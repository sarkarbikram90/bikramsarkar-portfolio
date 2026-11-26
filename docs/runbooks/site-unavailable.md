# Runbook: Site Unavailable (`bikramsarkar.space`)

- **Alert**: `[Critical] PortfolioOps Site Unavailable (bikramsarkar.space)`
- **Trigger**: External HTTPS homepage uptime check fails in `>= 2` probe regions for `2 minutes`.

## 1. Verify External Symptoms (1 min)

```bash
curl -svI https://bikramsarkar.space/healthz
curl -svI https://bikramsarkar.space/
dig +short bikramsarkar.space A
```

Determine which layer is failing:
- **DNS resolution error / wrong IP**: Check registrar `A` record against `terraform output -raw gateway_static_ip`.
- **TLS handshake / cert error**: Check Certificate Manager status (Step 2).
- **HTTP 502/503/504**: Check GKE Gateway, `HealthCheckPolicy`, and pods (Step 3).

## 2. Check TLS Certificate & Gateway Status (2 min)

```bash
gcloud certificate-manager certificates describe portfolio-cert --project=<PROJECT_ID>
kubectl get gateway,httproute,healthcheckpolicy -n portfolio
kubectl describe gateway portfolio-gateway -n portfolio
```

- Certificate state must be `ACTIVE`. If `PROVISIONING` or `FAILED`, verify the DNS authorization CNAME matches `terraform output dns_authorization_cname`.
- Gateway must show `PROGRAMMED: True` with the static IP attached.

## 3. Check Workloads & Argo CD Sync (2 min)

```bash
kubectl get pods,endpoints -n portfolio
kubectl rollout status deployment/portfolio -n portfolio --timeout=30s
kubectl get application portfolio -n argocd -o wide
```

- If pods are crashing or failing readiness probes, follow [pod-crashloop-and-rollback.md](pod-crashloop-and-rollback.md).
- If pods are `Ready` but Gateway returns `502`, follow [http-5xx-and-gateway.md](http-5xx-and-gateway.md).

## 4. Emergency Mitigation (Zero-Downtime Fallback)

Because static site assets remain at the repository root with `CNAME` intact, if GKE or the Load Balancer suffers a prolonged outage you can temporarily repoint `bikramsarkar.space` DNS back to GitHub Pages A records while investigating GKE offline.
