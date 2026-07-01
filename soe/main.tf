provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "mel-prod" {
  name     = "mel-prod"
  location = "Australia Southeast"

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

resource "azurerm_resource_group" "mel-dev" {
  name     = "mel-dev"
  location = "Australia East"

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

resource "azurerm_virtual_network" "mel-prod-vnet" {
  name                = "mel-prod-vnet"
  location            = azurerm_resource_group.mel-prod.location
  resource_group_name = azurerm_resource_group.mel-prod.name

  # Define total address space for the network.
  address_space = ["10.0.0.0/28"]

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

resource "azurerm_virtual_network" "mel-dev-vnet" {
  name                = "mel-dev-vnet"
  location            = azurerm_resource_group.mel-dev.location
  resource_group_name = azurerm_resource_group.mel-dev.name

  # Define total address space for the network.
  address_space = ["10.0.0.0/28"]

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

resource "azurerm_subnet" "mel-prod-vm-subnet" {
  name                 = "mel-prod-vm-subnet"
  resource_group_name  = azurerm_resource_group.mel-prod.name
  virtual_network_name = azurerm_virtual_network.mel-prod-vnet.name

  address_prefixes = ["10.0.0.0/29"]
}

resource "azurerm_subnet" "mel-prod-logs-subnet" {
  name                 = "mel-prod-logs-subnet"
  resource_group_name  = azurerm_resource_group.mel-prod.name
  virtual_network_name = azurerm_virtual_network.mel-prod-vnet.name
  address_prefixes     = ["10.0.0.8/29"]
}

resource "azurerm_subnet" "mel-dev-vm-subnet" {
  name                 = "mel-dev-vm-subnet"
  resource_group_name  = azurerm_resource_group.mel-dev.name
  virtual_network_name = azurerm_virtual_network.mel-dev-vnet.name
  address_prefixes     = ["10.0.0.0/29"]
}

resource "azurerm_subnet" "mel-dev-logs-subnet" {
  name                 = "mel-dev-logs-subnet"
  resource_group_name  = azurerm_resource_group.mel-dev.name
  virtual_network_name = azurerm_virtual_network.mel-dev-vnet.name
  address_prefixes     = ["10.0.0.8/29"]
}

resource "azurerm_storage_account" "mel-prod-storage" {
  name                     = "nigelmelbprodstorage"
  resource_group_name      = azurerm_resource_group.mel-prod.name
  location                 = azurerm_resource_group.mel-prod.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Cold"

  # Define some security settings.
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true # Versioning maintains previous versions of an object,
    # to access earlier versions of a blob for recovery or audit purposes if data is modified or deleted.
    # However, this can increase storage costs as multiple versions of a blob will exist.
    change_feed_enabled           = true # Enables a feed of changes to track modifications to blobs.
    change_feed_retention_in_days = 90   # Sets a hard limit on how long change feeds are kept.

    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }

}

resource "azurerm_storage_account" "mel-dev-storage" {
  name                     = "nigeldevstorage"
  resource_group_name      = azurerm_resource_group.mel-dev.name
  location                 = azurerm_resource_group.mel-dev.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Cold"

  # Define security settings.
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  infrastructure_encryption_enabled = true

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

resource "azurerm_storage_account" "mel-prod-log-acct" {
  name                     = "nigelmelbprodlogs"
  resource_group_name      = azurerm_resource_group.mel-prod.name
  location                 = azurerm_resource_group.mel-prod.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Cold"

  # Define security settings.
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true # Versioning maintains previous versions of an object,
    # to access earlier versions of a blob for recovery or audit purposes if data is modified or deleted.
    # However, this can increase storage costs as multiple versions of a blob will exist.
    change_feed_enabled           = true # Enables a feed of changes to track modifications to blobs.
    change_feed_retention_in_days = 90   # Sets a hard limit on how long change feeds are kept.

    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

resource "azurerm_storage_container" "mel-prod-logs-container" {
  name                  = "mel-prod-logs-container"
  storage_account_id    = azurerm_storage_account.mel-prod-log-acct.id
  container_access_type = "private"
}

resource "azurerm_storage_container_immutability_policy" "mel-prod-log-imm" {
  storage_container_resource_manager_id = azurerm_storage_container.mel-prod-logs-container.id
  immutability_period_in_days           = 14 # Sufficient for lab purposes
}

resource "azurerm_storage_account" "mel-dev-logs" {
  name                     = "nigelmelbdevlogs"
  resource_group_name      = azurerm_resource_group.mel-dev.name
  location                 = azurerm_resource_group.mel-dev.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Cold"

  # Define security settings.
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true # Versioning maintains previous versions of an object,
    # to access earlier versions of a blob for recovery or audit purposes if data is modified or deleted.
    # However, this can increase storage costs as multiple versions of a blob will exist.
    change_feed_enabled           = true # Enables a feed of changes to track modifications to blobs.
    change_feed_retention_in_days = 90   # Sets a hard limit on how long change feeds are kept.

    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    Project     = "GRC Engineering"
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

resource "azurerm_monitor_diagnostic_setting" "mel-prod-monitor" {
  name               = "${azurerm_resource_group.mel-prod.name}-logs"
  target_resource_id = "${azurerm_storage_account.mel-prod-storage.id}/blobServices/default"
  storage_account_id = azurerm_storage_account.mel-prod-log-acct.id

  # Defines the types of logs to capture.
  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}
