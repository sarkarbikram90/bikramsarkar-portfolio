# Remote state stored in a versioned, uniform-access GCS bucket.
# Initialize with:
#   terraform init -backend-config="bucket=<YOUR_STATE_BUCKET>"
terraform {
  backend "gcs" {
    prefix = "portfolio-ops/prod"
  }
}
