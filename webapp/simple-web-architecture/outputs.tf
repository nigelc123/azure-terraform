output "ResourceGroup" {
  value       = azurerm_resource_group.simple-webapp.name
  description = "Azure Resource Group that will host this project."
}

output "Location" {
  value       = azurerm_resource_group.simple-webapp.location
  description = "Azure region that hosts this project."
}

output "WebAppName" {
  value       = azurerm_linux_web_app.linux-webapp.name
  description = "Name of the web app."
}

output "WebAppURL" {
  value       = azurerm_linux_web_app.linux-webapp.default_hostname
  description = "Default URL for the web app."
}

output "WebAppApplicationStack" {
  value       = azurerm_linux_web_app.linux-webapp.site_config[0].application_stack[0].python_version
  description = "Application stack used for the web app."
}