output "attestor_name" {
  description = "Binary Authorization attestor name for CI attestation signing."
  value       = google_binary_authorization_attestor.ci.name
}

output "kms_key_version_id" {
  description = "Cloud KMS asymmetric key version resource ID used by gcloud container binauthz attestations sign-and-create."
  value       = data.google_kms_crypto_key_version.attestor.id
}
