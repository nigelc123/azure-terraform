# Create a Linux Web App. This first requires the creation of an Azure App Service Plan (ASP) to determine location, features, cost and compute resources associated with the app.
resource "azurerm_service_plan" "webapp-service-plan" {
  # Required arguments
  name                = "${var.project_name}-service-plan"
  resource_group_name = azurerm_resource_group.simple-webapp.name
  location            = azurerm_resource_group.simple-webapp.location
  os_type             = "Linux"
  sku_name            = "F1" # Free Plan, 1GB RAM, 1GB Storage, Shared Cores (60 CPU minutes/day)

  tags = local.required_tags
}

# Create the actual web app.
# Note that deployment of the actual code will be done separately, using the Azure CLI's method for uploading .zip archives.
# This could be done in a bash script, with appropriate Service Principal credentials in environment variables, however for now I will be doing a manual, interactive deployment.
# The code used is the same as what was used in the GUI version, located in ./msdocs-python-flask-webapp-quickstart
resource "azurerm_linux_web_app" "linux-webapp" {
  # Required arguments
  name                = "${var.project_name}2"
  resource_group_name = azurerm_resource_group.simple-webapp.name
  location            = azurerm_resource_group.simple-webapp.location
  service_plan_id     = azurerm_service_plan.webapp-service-plan.id


  enabled = true

  # Security settings
  end_to_end_tls_encryption_enabled = true
  https_only                        = true

  public_network_access_enabled = true # Public network access is allowed, however restricted in the site_config's ip_restriction block.

  site_config {
    ip_restriction {
      action      = "Allow"
      ip_address  = "${data.http.current_ip.response_body}/32" # This explicitly wants a CIDR block.
      name        = "AllowPersonalConnection"
      priority    = 300
      description = "Allow connection to the web server from my personal IP."
    }

    ip_restriction_default_action = "Deny" # Deny any traffic that doesn't meet any rules defined above.

    always_on = false # Must be False for F1 SKU.

    # Specify that we are using a Python web app.
    application_stack {
      python_version = "3.14"
    }
  }
  tags = local.required_tags
}