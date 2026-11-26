output "repository_id" {
  description = "Artifact Registry repository ID."
  value       = google_artifact_registry_repository.docker.repository_id
}

output "repository_name" {
  description = "Full resource name of the Artifact Registry repository."
  value       = google_artifact_registry_repository.docker.name
}

output "repository_url" {
  description = "Docker image repository prefix."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}
