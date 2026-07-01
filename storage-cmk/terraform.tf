terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.73.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.14.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
  }
}