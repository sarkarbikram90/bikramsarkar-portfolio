output "budget_name" {
  description = "Created billing budget resource name, if enabled."
  value       = try(google_billing_budget.monthly[0].name, null)
}
