terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}


## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.3.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = ">= 0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}


# A vnet is required for the storage account
resource "azurerm_virtual_network" "this" {
  name                = module.naming.virtual_network.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "this" {
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]

  service_endpoints = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "private" {
  name                 = "${module.naming.subnet.name_unique}-private"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/27"]

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_private_dns_zone" "table" {
  name                = "privatelink.table.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_private_dns_zone" "queue" {
  name                = "privatelink.queue.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone" "sites" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone" "scm" {
  name                = "scm.privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.this.name
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
}


module "storage_account" {
  source  = "Skittlebomb/res-storage-storageaccount/azurerm"
  version = "0.1.1"


  name                          = module.naming.storage_account.name_unique
  resource_group_name           = azurerm_resource_group.this.name
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true
  large_file_share_enabled      = true
  is_hns_enabled                = false

  network_rules = {
    default_action             = "Allow"                  # (Required) Defines the default action for network rules. Valid options are Allow and Deny.
    ip_rules                   = ["109.155.194.154"]      # (Optional) Defines the list of IP rules to apply to the storage account. Defaults to [].
    virtual_network_subnet_ids = [azurerm_subnet.this.id] # (Optional) Defines the list of virtual network subnet IDs to apply to the storage account. Defaults to [].
    bypass                     = ["AzureServices"]        # (Optional) Defines which traffic can bypass the network rules. Valid options are AzureServices and None. Defaults to [].
    private_link_access = [
      {
        endpoint_resource_id = "/subscriptions/1230de8b-618d-487a-a4fa-b9a253432b7e/resourcegroups/*/providers/Microsoft.Logic/workflows/*"
      }
    ]
  }

  containers = {}



  private_endpoints = {
    blob = {
      subresource_name              = "blob"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.blob.id]
      subnet_resource_id            = azurerm_subnet.private.id
    },
    queue = {
      subresource_name              = "queue"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.queue.id]
      subnet_resource_id            = azurerm_subnet.private.id
    },
    table = {
      subresource_name              = "table"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.table.id]
      subnet_resource_id            = azurerm_subnet.private.id
    },
    file = {
      subresource_name              = "file"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.file.id]
      subnet_resource_id            = azurerm_subnet.private.id
    }
  }
}



resource "azurerm_service_plan" "this" {
  name                = module.naming.app_service_plan.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Windows"
  sku_name            = "WS1"
}
# This is the module call
# Do not specify location here due to the randomization above.
# Leaving location as `null` will cause the module to use the resource group location
# with a data source.
module "logic_app_standard" {
  source = "../../"
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  # ...
  name                       = "${module.naming.app_service_plan.name_unique}-la"
  resource_group_name        = azurerm_resource_group.this.name
  app_service_plan_id        = azurerm_service_plan.this.id
  storage_account_access_key = module.storage_account.resource.primary_access_key
  storage_account_name       = module.storage_account.resource.name
  use_private_vnet           = true
  subnet_id                  = azurerm_subnet.this.id

  site_config = {
    always_on                     = true
    app_scale_limit               = 1
    ftps_state                    = "Disabled"
    http2_enabled                 = true
    public_network_access_enabled = true
    # ip_restriction = [
    #   {
    #     name        = "Allow"
    #     service_tag = "LogicApps"
    #     priority    = 100
    #     action      = "Allow"
    #     headers = {
    #       x_azure_fdid      = ["550e8400-e29b-41d4-a716-446655440000", "550e8400-e29b-41d4-a716-446655440001"] # Example valid UUIDs
    #       x_fd_health_probe = ["1"]
    #       x_forwarded_for   = ["172.16.4.0/24", "192.168.1.0/24"]
    #       x_forwarded_host  = ["example.com", "anotherexample.com"]
    #     }
    #   }
    # ]
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
  }


  identity = {
    type = "SystemAssigned"
  }


  private_endpoints = {
    sites = {
      subresource_name              = "sites"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.sites.id]
      subnet_resource_id            = azurerm_subnet.private.id
    }
  }

  diagnostic_settings = {
    diagnostic_settings1 = {
      name                  = "diag-${module.naming.app_service_plan.name_unique}"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
    }
  }
}
