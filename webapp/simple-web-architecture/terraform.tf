terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
  }
  required_version = "~> 1.17"
}