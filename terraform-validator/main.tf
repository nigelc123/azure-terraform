provider "azurerm" {
  features {}
}

locals {
  required_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_resource_group" "example" {
  name     = var.rg-name
  location = "Australia East"

  tags = local.required_tags
}

resource "azurerm_virtual_network" "example" {
  name                = "${var.project-name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  tags = local.required_tags
}

# resource "azurerm_resource_group" "new-group" {
#   name     = "New-Group"
#   location = "Australia East"

#   tags = local.required_tags
# }


