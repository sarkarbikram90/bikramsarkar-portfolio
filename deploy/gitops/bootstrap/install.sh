#!/usr/bin/env bash
# Bootstrap lean Argo CD onto the GKE Autopilot cluster and register the root App-of-Apps.
# Prerequisite: kubectl is authenticated to portfolio-gke (see terraform output kubectl_credentials_command).

set -euo pipefail

ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-7.8.28}"

helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version "${ARGOCD_CHART_VERSION}" \
  --values deploy/gitops/bootstrap/argocd/values-lean.yaml \
  --wait \
  --timeout 10m

kubectl apply -f deploy/gitops/bootstrap/argocd/project-portfolio.yaml
kubectl apply -f deploy/gitops/bootstrap/argocd/root-app.yaml

echo ""
echo "Lean Argo CD bootstrapped."
echo "Fetch initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "Open UI locally (never exposed publicly):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8443:443"
