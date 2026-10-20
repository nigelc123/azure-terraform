variable "project-name" {
type = string
description = "Short description for the project."
default = "tf-validator"
}

variable "environment" {
type = string
description = "Environment that the project will be deployed to."
default = "dev"
}

variable "rg-name" {
type = string
description = "Name of the resource group."
default = "test-rg"
}