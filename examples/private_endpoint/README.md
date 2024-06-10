<!-- BEGIN_TF_DOCS -->
# Diagnostics example

This example shows how to enable diagnostics for the module.

```hcl
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
  virtual_network_subnet_id  = azurerm_subnet.this.id

  site_config = {
    always_on                     = true
    app_scale_limit               = 1
    ftps_state                    = "Disabled"
    http2_enabled                 = true
    public_network_access_enabled = true
    ip_restriction = [
      {
        name        = "Allow"
        service_tag = "LogicApps"
        priority    = 100
        action      = "Allow"
        headers = {
          x_azure_fdid      = ["550e8400-e29b-41d4-a716-446655440000", "550e8400-e29b-41d4-a716-446655440001"] # Example valid UUIDs
          x_fd_health_probe = ["1"]
          x_forwarded_for   = ["172.16.4.0/24", "192.168.1.0/24"]
          x_forwarded_host  = ["example.com", "anotherexample.com"]
        }
      }
    ]
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





# resource "azurerm_app_service_virtual_network_swift_connection" "this" {
#   app_service_id = module.logic_app_standard.logic_app_standard.id
#   subnet_id      = azurerm_subnet.this.id
# }
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.3.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0, < 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0, < 4.0.0)

## Resources

The following resources are used by this module:

- [azurerm_log_analytics_workspace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) (resource)
- [azurerm_private_dns_zone.blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_private_dns_zone.file](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_private_dns_zone.queue](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_private_dns_zone.scm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_private_dns_zone.sites](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_private_dns_zone.table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_service_plan.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) (resource)
- [azurerm_subnet.private](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

No outputs.

## Modules

The following Modules are called:

### <a name="module_logic_app_standard"></a> [logic\_app\_standard](#module\_logic\_app\_standard)

Source: ../../

Version:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: >= 0.3.0

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/regions/azurerm

Version: >= 0.3.0

### <a name="module_storage_account"></a> [storage\_account](#module\_storage\_account)

Source: Skittlebomb/res-storage-storageaccount/azurerm

Version: 0.1.1

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->