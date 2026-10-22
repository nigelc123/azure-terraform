provider "azurerm" {
  features {}
}

# Used to obtain the current public IP address of the machine that Terraform is running on.
# Only used for the purpose of this lab, to later allow access to the web server from my personal machine.
data "http" "current_ip" {
  url = "https://api.ipify.org"
}

# Set required tags for the resources, instead of having to repeat across each resources.
locals {
  required_tags = {
    Project   = var.project_name
    ManagedBy = var.managed_by
  }
}

# Create a Resource Group for this project.
resource "azurerm_resource_group" "simple-webapp" {
  name     = "${var.project_name}-rg"
  location = "Australia East"

  tags = local.required_tags
}


