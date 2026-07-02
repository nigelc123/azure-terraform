provider "azurerm" {
  features {}
}

# Ensure that service principal details have been exported to environment variables.
# This obtains data about the currently logged in user (which should be the authenticated Terraform SP)
data "azurerm_client_config" "current" {}

# This is used to send a HTTP request to the url to obtain my IP address.
# This is instead of hard-coding my IP address.
data "http" "current_ip" {
  url = "https://api.ipify.org"
}

# Define some required tags that I want within the locals block.
locals {
  required_labels = {
    Project         = var.project_label
    Environment     = var.environment
    ManagedBy       = "Terraform"
    ComplianceScope = "Test Storage Accounts"
  }

  storage_acc_name = "${var.project_label}${var.environment}"
  keyvault_name    = "${local.storage_acc_name}-vault"
  key_id           = "${local.storage_acc_name}-key"
}

# Create a Resource Group for the lab.
resource "azurerm_resource_group" "tf-storage-cmk" {
  name     = "tf-storage-cmk"
  location = "Australia Central"
  tags     = local.required_labels
}

# Create an Azure Key Vault within the Resource Group just created.
resource "azurerm_key_vault" "tf-storage-kv" {
  # Required parameters.
  name                = local.keyvault_name
  location            = azurerm_resource_group.tf-storage-cmk.location
  resource_group_name = azurerm_resource_group.tf-storage-cmk.name
  sku_name            = "standard" # Standard for the purposes of the lab.

  # Obtains the tenant ID based on the currently logged in service principal. Avoids hard coding the tenant ID.
  tenant_id = data.azurerm_client_config.current.tenant_id

# CEK-20: Key Recovery
  # Enable purge protection and soft delete. Set soft delete for 7 days so I can delete asap without additional charges.
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  # Don't allow access from public networks.
  public_network_access_enabled = true

  #Wasn't working without this, potentially because the IP was being blocked by the above.
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"                                    # Deny by default.
    ip_rules       = ["${data.http.current_ip.response_body}"] # Use IP address obtained.
  }

  # Enable RBAC authorisation, this allows me to assign the correct RBAC role to the Managed Identity later on.
  rbac_authorization_enabled = true

  # Add tags for hypothetical additional filtering scenarios.
  tags = local.required_labels
}

# Create a role assignment for the Terraform Service Principal.
# The creator of the Key Vault doesn't implicitly get admin rights over it. This explicitly assigns the role.
resource "azurerm_role_assignment" "tf-sp-role" {
  scope = azurerm_key_vault.tf-storage-kv.id

  # This is the minimum role needed to perform actions on keys in a key vault.
  role_definition_name = "Key Vault Administrator"

  # Assigns the role to the service principal based on ID. Uses a data field to avoid hard-coding the ID.
  principal_id = data.azurerm_client_config.current.object_id

}

# This is a time sleep function which waits 2 minutes after the role has been created.
# This gives time for RBAC to properly propagate.
resource "time_sleep" "wait_for_rbac" {
  create_duration = "2m"                                 # Wait 2 minutes after creation.
  depends_on      = [azurerm_role_assignment.tf-sp-role] # Wait after the creation of the tf-sp-role
}

# Create the Key within the Key Vault.
resource "azurerm_key_vault_key" "tf-storage-key" {
  # Required parameters
  name         = "${local.keyvault_name}-key"
  key_vault_id = azurerm_key_vault.tf-storage-kv.id

  # This block is used to define the cryptographic operations the key can be used for.
  # We only need Wrap and UnwrapKey because this is what's needed to encrypt and decrypt the
  # Storage Account's Account Encryption Key. This restricts the operations to the minimum required.
  key_opts = [
    "unwrapKey",
    "wrapKey"
  ]

# CEK-04: Encryption Algorithm
# CEK-10: Key Generation
  # Set the key type, I have set it to RSA (asymmetric encryption algorithm) with a key size of 4096 bits.
  key_type = "RSA" 
  key_size = 4096

  # Wait for the time_sleep to be complete before creating the vault. 
  # Allows RBAC time to propagate.
  depends_on = [time_sleep.wait_for_rbac]
  tags       = local.required_labels
}

# Create the Storage Account.
resource "azurerm_storage_account" "storage-acc" {
  # Required parameters.
  name                = local.storage_acc_name
  resource_group_name = azurerm_resource_group.tf-storage-cmk.name
  location            = azurerm_resource_group.tf-storage-cmk.location

  # Set account type details.
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  # Security settings.
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true # If this was false, this would override network rules.
  infrastructure_encryption_enabled = true # CEK-03: Data Encryption.

  # The network_rules block is used to allow access to the Storage Account from my personal IP address.
  network_rules {
    bypass         = ["AzureServices"]
    default_action = "Deny"                                    # Deny by default.
    ip_rules       = ["${data.http.current_ip.response_body}"] # Use IP address obtained.
  }

  # Wait for the Azure RBAC role to be assigned to the Managed Identity we are creating for the Storage Account.
  depends_on = [azurerm_role_assignment.tf-crypto-user]

  # Define blob properties including versioning for recovery purposes.
  blob_properties {
    versioning_enabled            = true
    change_feed_enabled           = true
    change_feed_retention_in_days = 7

    delete_retention_policy {
      days = 7
    }
  }
 # CEK-03: Data Encryption.
  # Assign a Customer Managed Key to use for encryption.
  # This will be the key we created, and we need an identity for the storage account to use to authenticate to Key Vault.
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.tf-storage-key.id
    user_assigned_identity_id = azurerm_user_assigned_identity.tf-storage-kv-user.id
  }

  # This tells the storage account which identity to use.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.tf-storage-kv-user.id]
  }

  tags = local.required_labels
}

# Create a storage container within the account for testing purposes.
resource "azurerm_storage_container" "test-container" {
  name               = "testcontainer"
  storage_account_id = azurerm_storage_account.storage-acc.id
}

# Create a User-Assigned Managed Identity for the storage account.
# This is the identity that the storage account will use to authenticate to Key Vault.
# This allows for the key to perform wrap and unwrap actions on the Account Encryption Key.
resource "azurerm_user_assigned_identity" "tf-storage-kv-user" {
  location            = azurerm_resource_group.tf-storage-cmk.location
  name                = "${var.project_label}-crypto-kv-user"
  resource_group_name = azurerm_resource_group.tf-storage-cmk.name

  tags = local.required_labels
}

# Assign the correct role to the user assigned managed identity.
# This allows the user assigned managed identity to perform crypto actions.
resource "azurerm_role_assignment" "tf-crypto-user" {
  scope                = azurerm_key_vault.tf-storage-kv.id # Applies the role assignment on the Key Vault we created.
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.tf-storage-kv-user.principal_id # Assigns the role to the identity we created.

  # We need the identity to be created, and the Terraform Service Principal to have the correct role before we attempt this, otherwise the permissions may not actually be authorised..
  depends_on = [azurerm_user_assigned_identity.tf-storage-kv-user, azurerm_role_assignment.tf-sp-role]
}