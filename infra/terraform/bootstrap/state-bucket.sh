#!/usr/bin/env bash
# One-time bootstrap script to create the hardened GCS bucket for Terraform remote state.
# Usage: ./infra/terraform/bootstrap/state-bucket.sh <GCP_PROJECT_ID> [REGION]

set -euo pipefail

PROJECT_ID="${1:?Usage: $0 <GCP_PROJECT_ID> [REGION]}"
REGION="${2:-us-central1}"
BUCKET_NAME="${PROJECT_ID}-tfstate-portfolio-ops"

echo "Creating Terraform state bucket: gs://${BUCKET_NAME} in ${REGION}..."

gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --uniform-bucket-level-access \
  --public-access-prevention

gcloud storage buckets update "gs://${BUCKET_NAME}" \
  --versioning

echo "Done. Initialize Terraform with:"
echo "  cd infra/terraform/environments/prod"
echo "  terraform init -backend-config=\"bucket=${BUCKET_NAME}\""
