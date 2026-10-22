variable "project_name" {
  type        = string
  description = "Short descriptor of the project."

  validation {
    condition     = can(regex("^[a-z0-9-]{2,40}$", var.project_name))
    error_message = "Use lowercase letters, numbers and hyphens only."
  }
}

variable "managed_by" {
  type        = string
  description = "How the resource is managed."
  default     = "Terraform"
}