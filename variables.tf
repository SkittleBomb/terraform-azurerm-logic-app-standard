variable "location" {
  type        = string
  default     = null
  description = "Azure region where the resource should be deployed.  If null, the location will be inferred from the resource group location."
}
# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

variable "name" {
  description = "Specifies the name of the Logic App"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.name))
    error_message = "The name must be between 1 and 64 characters long and can only contain letters, numbers, underscores, and hyphens."
  }
}


variable "app_service_plan_id" {
  description = "The ID of the App Service Plan within which to create this Logic App"
  type        = string

}

variable "app_settings" {
  description = "A map of key-value pairs for App Settings and custom values"
  type        = map(string)
  default     = {}
}

variable "use_extension_bundle" {
  description = "Should the logic app use the bundled extension package?"
  type        = bool
  default     = true
}

variable "bundle_version" {
  description = "If use_extension_bundle then controls the allowed range for bundle versions"
  type        = string
  default     = "[1.*, 2.0.0)"
}

variable "connection_string" {
  type = object({
    name  = string
    type  = string
    value = string
  })
  default     = null
  description = <<DESCRIPTION
A list of connection_string blocks that support the following:
- `name` - (Required) The name of the Connection String.
- `type` - (Required) The type of the Connection String. Possible values are APIHub, Custom, DocDb, EventHub, MySQL, NotificationHub, PostgreSQL, RedisCache, ServiceBus, SQLAzure, and SQLServer.
- `value` - (Required) The value for the Connection String.
DESCRIPTION
}

variable "client_affinity_enabled" {
  description = "Should the Logic App send session affinity cookies, which route client requests in the same session to the same instance?"
  type        = bool
  default     = false
}

variable "client_certificate_mode" {
  description = "The mode of the Logic App's client certificates requirement for incoming requests"
  type        = string
  default     = "Optional"

  validation {
    condition     = contains(["Optional", "Required"], var.client_certificate_mode)
    error_message = "The client_certificate_mode must be either 'Optional' or 'Required'."
  }
}

variable "enabled" {
  description = "Is the Logic App enabled?"
  type        = bool
  default     = true
}

variable "https_only" {
  description = "Can the Logic App only be accessed via HTTPS?"
  type        = bool
  default     = true
}

variable "identity" {
  type = object({
    type         = string
    identity_ids = optional(list(string))
  })
  default = {
    type         = "SystemAssigned"
    identity_ids = []
  }

  description = <<DESCRIPTION
An identity block that supports the following:
- `type` - (Required) Specifies the type of Managed Service Identity that should be configured on this Logic App Standard. Possible values are SystemAssigned, UserAssigned and SystemAssigned, UserAssigned (to enable both).
- `identity_ids` - (Optional) Specifies a list of User Assigned Managed Identity IDs to be assigned to this Logic App Standard.

NOTE:
When type is set to SystemAssigned, The assigned principal_id and tenant_id can be retrieved after the Logic App has been created. More details are available below.

NOTE:
The identity_ids is required when type is set to UserAssigned or SystemAssigned, UserAssigned.
DESCRIPTION

  validation {
    condition     = var.identity != null && contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], var.identity.type)
    error_message = "The type must be either 'SystemAssigned', 'UserAssigned' or 'SystemAssigned, UserAssigned'."
  }
}

variable "site_config" {
  type = object({
    always_on       = optional(bool)
    app_scale_limit = optional(number)
    cors = optional(object({
      allowed_origins     = list(string)
      support_credentials = optional(bool)
    }))
    dotnet_framework_version         = optional(string)
    elastic_instance_minimum         = optional(number)
    ftps_state                       = optional(string)
    health_check_path                = optional(string)
    http2_enabled                    = optional(bool)
    ip_restriction                   = optional(list(object({ ip_address = optional(string), service_tag = optional(string), virtual_network_subnet_id = optional(string), name = optional(string), priority = optional(number), action = optional(string), headers = optional(list(string)) })))
    scm_ip_restriction               = optional(list(object({ ip_address = optional(string), service_tag = optional(string), virtual_network_subnet_id = optional(string), name = optional(string), priority = optional(number), action = optional(string), headers = optional(list(string)) })))
    scm_use_main_ip_restriction      = optional(bool)
    scm_min_tls_version              = optional(string)
    scm_type                         = optional(string)
    linux_fx_version                 = optional(string)
    min_tls_version                  = optional(string)
    pre_warmed_instance_count        = optional(number)
    public_network_access_enabled    = optional(bool)
    runtime_scale_monitoring_enabled = optional(bool)
    use_32_bit_worker_process        = optional(bool)
    vnet_route_all_enabled           = optional(bool)
    websockets_enabled               = optional(bool)
  })
  default     = {}
  description = <<DESCRIPTION
A site_config block that supports the following:
- `always_on` - (Optional) Should the Logic App be loaded at all times? Defaults to false.
- `app_scale_limit` - (Optional) The number of workers this Logic App can scale out to. Only applicable to apps on the Consumption and Premium plan.
- `cors` - (Optional) A cors block as defined below.
  - `allowed_origins` - (Required) A list of origins which should be able to make cross-origin calls. * can be used to allow all calls.
  - `support_credentials` - (Optional) Are credentials supported?
- `dotnet_framework_version` - (Optional) The version of the .NET framework's CLR used in this Logic App Possible values are v4.0 (including .NET Core 2.1 and 3.1), v5.0 and v6.0. For more information on which .NET Framework version to use based on the runtime version you're targeting - please see this table. Defaults to v4.0.
- `elastic_instance_minimum` - (Optional) The number of minimum instances for this Logic App Only affects apps on the Premium plan.
- `ftps_state` - (Optional) State of FTP / FTPS service for this Logic App Possible values include: AllAllowed, FtpsOnly and Disabled. Defaults to AllAllowed.
- `health_check_path` - (Optional) Path which will be checked for this Logic App health.
- `http2_enabled` - (Optional) Specifies whether or not the HTTP2 protocol should be enabled. Defaults to false.
- `ip_restriction` - (Optional) A list of ip_restriction objects representing IP restrictions as defined below.
  - `ip_address` - (Optional) The IP Address used for this IP Restriction in CIDR notation.
  - `service_tag` - (Optional) The Service Tag used for this IP Restriction.
  - `virtual_network_subnet_id` - (Optional) The Virtual Network Subnet ID used for this IP Restriction.
  - `name` - (Optional) The name for this IP Restriction.
  - `priority` - (Optional) The priority for this IP Restriction. Restrictions are enforced in priority order. By default, the priority is set to 65000 if not specified.
  - `action` - (Optional) Does this restriction Allow or Deny access for this IP range. Defaults to Allow.
 - `headers` - (Optional) The headers block for this specific as a ip_restriction block as defined below.
    - `x_azure_fdid` - (Optional) A list of allowed Azure FrontDoor IDs in UUID notation with a maximum of 8.
    - `x_fd_health_probe` - (Optional) A list to allow the Azure FrontDoor health probe header. Only allowed value is "1".
    - `x_forwarded_for` - (Optional) A list of allowed 'X-Forwarded-For' IPs in CIDR notation with a maximum of 8.
    - `x_forwarded_host` - (Optional) A list of allowed 'X-Forwarded-Host' domains with a maximum of 8.
- `scm_ip_restriction` - (Optional) A list of scm_ip_restriction objects representing SCM IP restrictions as defined below.
  - `ip_address` - (Optional) The IP Address used for this IP Restriction in CIDR notation.
  - `service_tag` - (Optional) The Service Tag used for this IP Restriction.
  - `virtual_network_subnet_id` - (Optional) The Virtual Network Subnet ID used for this IP Restriction.
  - `name` - (Optional) The name for this IP Restriction.
  - `priority` - (Optional) The priority for this IP Restriction. Restrictions are enforced in priority order. By default, the priority is set to 65000 if not specified.
  - `action` - (Optional) Does this restriction Allow or Deny access for this IP range. Defaults to Allow.
  - `headers` - (Optional) The headers block for this specific as a scm_ip_restriction block as defined below.
- `scm_use_main_ip_restriction` - (Optional) Should the Logic App ip_restriction configuration be used for the SCM too. Defaults to false.
- `scm_min_tls_version` - (Optional) Configures the minimum version of TLS required for SSL requests to the SCM site. Possible values are 1.0, 1.1 and 1.2.
- `scm_type` - (Optional) The type of Source Control used by the Logic App in use by the Windows Function App. Defaults to None. Possible values are: BitbucketGit, BitbucketHg, CodePlexGit, CodePlexHg, Dropbox, ExternalGit, ExternalHg, GitHub, LocalGit, None, OneDrive, Tfs, VSO, and VSTSRM
- `linux_fx_version` - (Optional) Linux App Framework and version for the AppService, e.g. DOCKER|(golang:latest). Setting this value will also set the kind of application deployed to functionapp,linux,container,workflowapp
- `min_tls_version` - (Optional) The minimum supported TLS version for the Logic App Possible values are 1.0, 1.1, and 1.2. Defaults to 1.2 for new Logic Apps.
- `pre_warmed_instance_count` - (Optional) The number of pre-warmed instances for this Logic App Only affects apps on the Premium plan.
- `public_network_access_enabled` - (Optional) Is public network access enabled? Defaults to true.
- `runtime_scale_monitoring_enabled` - (Optional) Should Runtime Scale Monitoring be enabled?. Only applicable to apps on the Premium plan. Defaults to false.
- `use_32_bit_worker_process` - (Optional) Should the Logic App run in 32 bit mode, rather than 64 bit mode? Defaults to true.
- `vnet_route_all_enabled` - (Optional) Should all outbound traffic to have Virtual Network Security Groups and User Defined Routes applied.
- `websockets_enabled` - (Optional) Should WebSockets be enabled?
DESCRIPTION
}

variable "storage_account_name" {
  description = "The backend storage account name which will be used by this Logic App (e.g. for Stateful workflows data)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "The storage_account_name must be between 3 and 24 characters long and can only contain lowercase letters and numbers."
  }
}

variable "storage_account_access_key" {
  description = "The access key which will be used to access the backend storage account for the Logic App"
  type        = string
}

variable "storage_account_share_name" {
  description = "The name of the share used by the logic app, if you want to use a custom name"
  type        = string
  default     = ""
}

variable "app_version" {
  description = "The runtime version associated with the Logic App"
  type        = string
  default     = "~4"
}

variable "virtual_network_subnet_id" {
  description = "The subnet id which will be used by this resource for regional virtual network integration"
  type        = string
  default     = ""
}


variable "customer_managed_key" {
  type = object({
    key_vault_resource_id = string
    key_name              = string
    key_version           = optional(string, null)
    user_assigned_identity = optional(object({
      resource_id = string
    }), null)
  })
  default     = null
  description = <<DESCRIPTION
A map describing customer-managed keys to associate with the resource. This includes the following properties:
- `key_vault_resource_id` - The resource ID of the Key Vault where the key is stored.
- `key_name` - The name of the key.
- `key_version` - (Optional) The version of the key. If not specified, the latest version is used.
- `user_assigned_identity` - (Optional) An object representing a user-assigned identity with the following properties:
  - `resource_id` - The resource ID of the user-assigned identity.
DESCRIPTION  
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
- `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.
DESCRIPTION  
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
}


variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the Managed Identity configuration on this resource. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
DESCRIPTION
  nullable    = false
}

variable "private_endpoints" {
  type = map(object({
    name = optional(string, null)
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
    })), {})
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags                                    = optional(map(string), null)
    subnet_resource_id                      = string
    private_dns_zone_group_name             = optional(string, "default")
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_associations = optional(map(string), {})
    private_service_connection_name         = optional(string, null)
    network_interface_name                  = optional(string, null)
    location                                = optional(string, null)
    resource_group_name                     = optional(string, null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of private endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `role_assignments` - (Optional) A map of role assignments to create on the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time. See `var.role_assignments` for more information.
- `lock` - (Optional) The lock level to apply to the private endpoint. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
- `tags` - (Optional) A mapping of tags to assign to the private endpoint.
- `subnet_resource_id` - The resource ID of the subnet to deploy the private endpoint in.
- `private_dns_zone_group_name` - (Optional) The name of the private DNS zone group. One will be generated if not set.
- `private_dns_zone_resource_ids` - (Optional) A set of resource IDs of private DNS zones to associate with the private endpoint. If not set, no zone groups will be created and the private endpoint will not be associated with any private DNS zones. DNS records must be managed external to this module.
- `application_security_group_resource_ids` - (Optional) A map of resource IDs of application security groups to associate with the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
- `private_service_connection_name` - (Optional) The name of the private service connection. One will be generated if not set.
- `network_interface_name` - (Optional) The name of the network interface. One will be generated if not set.
- `location` - (Optional) The Azure location where the resources will be deployed. Defaults to the location of the resource group.
- `resource_group_name` - (Optional) The resource group where the resources will be deployed. Defaults to the resource group of this resource.
- `ip_configurations` - (Optional) A map of IP configurations to create on the private endpoint. If not specified the platform will create one. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  - `name` - The name of the IP configuration.
  - `private_ip_address` - The private IP address of the IP configuration.
DESCRIPTION
  nullable    = false
}

# This variable is used to determine if the private_dns_zone_group block should be included,
# or if it is to be managed externally, e.g. using Azure Policy.
# https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault/issues/32
# Alternatively you can use AzAPI, which does not have this issue.
variable "private_endpoints_manage_dns_zone_group" {
  type        = bool
  default     = true
  description = "Whether to manage private DNS zone groups with this module. If set to false, you must manage private DNS zone groups externally, e.g. using Azure Policy."
  nullable    = false
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}
