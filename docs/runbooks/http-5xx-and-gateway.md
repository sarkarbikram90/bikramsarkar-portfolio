# Runbook: Gateway HTTP 5xx Spike & High Latency

- **Alerts**:
  - `[Critical] PortfolioOps Gateway HTTP 5xx Spike` (`> 5` 5xx responses in 5m)
  - `[Warning] PortfolioOps High p95 Latency (>500ms)` (sustained 10m)

## 1. Inspect Structured Nginx & Load Balancer Logs

Run in **Cloud Logging**:

```text
resource.type="k8s_container"
resource.labels.namespace_name="portfolio"
jsonPayload.httpRequest.status>=500
```

Check GCP Load Balancer logs for backend failures (`statusDetails` such as `backend_connection_closed_before_data_sent_to_client` or `failed_to_pick_backend`):

```text
resource.type="http_load_balancer"
httpRequest.status>=500
```

## 2. Verify Backend Health Checks & NetworkPolicy

```bash
kubectl get healthcheckpolicy,httproute,service,endpoints -n portfolio
kubectl describe healthcheckpolicy portfolio -n portfolio
kubectl get networkpolicy -n portfolio -o yaml
```

Common root causes on GKE Gateway:
- **`failed_to_pick_backend` (502/503)**: GCP health checks (`130.211.0.0/22`, `35.191.0.0/16`) are blocked by `NetworkPolicy` or `/healthz` is returning non-200. Confirm `networkPolicy.ingressCidrs` includes both Google Front End ranges on port `8080`.
- **Connection resets during rollout**: Confirm `preStop: sleep 5` and `maxUnavailable: 0` are intact in the Deployment so the Load Balancer drains endpoints before pod termination.
- **High latency (`>500ms` p95)**: Check `PortfolioOps — SRE Overview` dashboard for CPU throttling (`cpu/limit_utilization`) or unexpected traffic surge; if CPU is saturated, enable `autoscaling.enabled: true` in `deploy/gitops/envs/prod/values-portfolio.yaml`.
