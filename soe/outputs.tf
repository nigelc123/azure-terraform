output "Prod_Resource_Group_Location" {
  description = "Location of the production resource group."
  value       = azurerm_resource_group.mel-prod.location

  precondition {
    condition     = strcontains(azurerm_resource_group.mel-prod.location, "australia") == true
    error_message = "Resources in this subscription must be deployed to Australia. Please check the configuration."
  }
}

output "Dev_Resource_Group_Location" {
  description = "Location of the development resource group."
  value       = azurerm_resource_group.mel-dev.location

  precondition {
    condition     = strcontains(azurerm_resource_group.mel-dev.location, "australia") == true
    error_message = "Resources in this subscription must be deployed to Australia for compliance reasons. Please check the configuration."
  }
}

output "Prod_Primary_Storage_Account_Name" {
  description = "Name of the production storage account."
  value       = azurerm_storage_account.mel-prod-storage.name
}

# output "Prod_Primary_Storage_Account_Security_Configs" {
#   value = [azurerm_storage_account.mel-prod-storage.https_traffic_only_enabled, azurerm_storage_account.mel-prod-storage.min_tls_version, azurerm_storage_account.mel-prod-storage.public_network_access_enabled, azurerm_storage_account.mel-prod-storage.infrastructure_encryption_enabled]
# }

output "Prod_Storage_HTTPS" {
  description = "Outputs whether the production storage account only accepts HTTPS traffic."
  value       = azurerm_storage_account.mel-prod-storage.https_traffic_only_enabled

  precondition {
    condition     = azurerm_storage_account.mel-prod-storage.https_traffic_only_enabled == true
    error_message = "Storage accounts should only accept HTTPS traffic by default. Please check the configuration."
  }
}

output "Prod_Storage_Min_TLS" {
  description = "Outputs the minimum TLS version accepted by the Storage account."
  value       = azurerm_storage_account.mel-prod-storage.min_tls_version

  precondition {
    condition     = azurerm_storage_account.mel-prod-storage.min_tls_version == "TLS1_2"
    error_message = "Storage accounts should be configured with a minimum TLS version of v1.2. Please check the configuration."
  }
}

output "Prod_Storage_Public_Access" {
  description = "Outputs whether the storage account accepts public network access."
  value       = azurerm_storage_account.mel-prod-storage.public_network_access_enabled

  precondition {
    condition     = azurerm_storage_account.mel-prod-storage.public_network_access_enabled == false
    error_message = "Storage accounts should not accept access from public, untrusted networks by default. Please check the configuration."
  }
}

output "Prod_Storage_Infra_Encryption" {
  description = "Outputs whether the storage account has infrastructure encryption enabled."
  value       = azurerm_storage_account.mel-prod-storage.infrastructure_encryption_enabled

  precondition {
    condition     = azurerm_storage_account.mel-prod-storage.infrastructure_encryption_enabled == true
    error_message = "Storage accounts should have infrastructure encryption enabled by default. Please check the configuration."
  }
}

output "Prod_Storage_Account_Blob_Versioning_Settings" {
  description = "Outputs whether blob versioning is enabled for the storage account."
  value       = one([for property in azurerm_storage_account.mel-prod-storage.blob_properties : property.versioning_enabled])

  precondition {
    condition     = one([for property in azurerm_storage_account.mel-prod-storage.blob_properties : property.versioning_enabled]) == true
    error_message = " Blob versioning must be enabled for storage accounts. Please check the configuration."
  }
}

output "Dev_Primary_Storage_Account_Name" {
  description = "The name of the development storage account."
  value       = azurerm_storage_account.mel-dev-storage.name
}

output "Dev_Primary_Storage_Account_Security_Configs" {
  value = [azurerm_storage_account.mel-dev-storage.https_traffic_only_enabled, azurerm_storage_account.mel-dev-storage.min_tls_version, azurerm_storage_account.mel-dev-storage.public_network_access_enabled, azurerm_storage_account.mel-dev-storage.infrastructure_encryption_enabled]
}