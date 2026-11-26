variable "billing_account_id" {
  type        = string
  description = "GCP Billing Account ID (leave empty to skip budget creation)."
  default     = ""
}

variable "project_number" {
  type        = string
  description = "Numerical GCP project number."
  default     = ""
}

variable "name_prefix" {
  type        = string
  description = "Budget naming prefix."
  default     = "portfolio-ops"
}

variable "monthly_budget_amount" {
  type        = number
  description = "Monthly budget threshold in whole currency units (after GCP credits)."
  default     = 60
}

variable "currency_code" {
  type        = string
  description = "ISO-4217 currency code."
  default     = "USD"
}
