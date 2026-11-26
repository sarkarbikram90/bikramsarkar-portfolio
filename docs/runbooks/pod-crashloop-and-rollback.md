# Runbook: Pod CrashLoopBackOff & GitOps Rollback

- **Alert**: `[Critical] PortfolioOps Container Restart Loop (portfolio)`
- **Trigger**: Container restarts `> 2` in a 10-minute window inside namespace `portfolio`.

## 1. Inspect Failing Pod & Previous Container Logs

```bash
kubectl get pods -n portfolio -o wide
kubectl describe pod -n portfolio <POD_NAME>
kubectl logs -n portfolio <POD_NAME> -c portfolio --previous --tail=100
```

Check `Last State` / `Reason` in `kubectl describe`:
- **`OOMKilled`**: Container exceeded `128Mi` limit (or sidecar exceeded `64Mi`). Check recent Nginx/exporter config changes.
- **`CreateContainerConfigError` / permission denied**: Verify `readOnlyRootFilesystem: true` has `/tmp` and `/var/cache/nginx` `emptyDir` mounts and UID/GID `10101` matches file ownership in `deploy/docker/Dockerfile`.
- **`ImagePullBackOff`**: Verify the `@sha256` digest exists in `us-central1-docker.pkg.dev/<PROJECT_ID>/portfolio-images/portfolio` and the GKE node SA has `roles/artifactregistry.reader`.
- **Liveness probe failure**: Test `/healthz` locally inside a healthy pod or check Nginx error logs.

## 2. Roll Back Safely via GitOps

If a recent image or Helm change caused the crash loop, revert the commit on `main`:

```bash
git log -n 5 --oneline deploy/
git revert <BAD_COMMIT_SHA>
git push origin main
```

Watch Argo CD self-heal and verify `2/2` replicas reach `Ready`:

```bash
kubectl rollout status deployment/portfolio -n portfolio
kubectl get pods -n portfolio
```
