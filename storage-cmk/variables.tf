variable "project_label" {
  type        = string
  description = "Short project identifier."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,15}$", var.project_label))
    error_message = "Project Label must be 3-14 lowercase alphanumeric characters, and start with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment - 'dev', 'test' or 'prod'."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be 'dev','test' or 'prod'."
  }
}