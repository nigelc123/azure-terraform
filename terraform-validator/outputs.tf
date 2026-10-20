output "resource_group_id" {
  description = "Resource Group ID."
  value       = azurerm_resource_group.example.id
}

output "vnet_id" {
  description = "Virtual Network ID."
  value       = azurerm_virtual_network.example.id
}