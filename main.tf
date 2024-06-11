data "azurerm_resource_group" "parent" {
  count = var.location == null ? 1 : 0

  name = var.resource_group_name
}

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_logic_app_standard.this.id # TODO: Replace with your azurerm resource name
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_logic_app_standard.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azurerm_logic_app_standard" "this" {
  name                       = var.name
  location                   = coalesce(var.location, local.resource_group_location)
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = var.app_service_plan_id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_access_key
  storage_account_share_name = try(var.storage_account_share_name, null)
  version                    = try(var.app_version, "~4")
  use_extension_bundle       = try(var.use_extension_bundle, true)
  bundle_version             = try(var.bundle_version, "[1.*, 2.0.0)")
  client_affinity_enabled    = try(var.client_affinity_enabled, false)
  client_certificate_mode    = try(var.client_certificate_mode, "Optional")
  enabled                    = try(var.enabled, true)
  https_only                 = try(var.https_only, true)
  virtual_network_subnet_id  = var.virtual_network_subnet_id != "" ? var.virtual_network_subnet_id : null

  dynamic "identity" {
    for_each = var.identity != null ? [var.identity] : [{ type = null, identity_ids = [] }]
    content {
      type         = identity.value.type
      identity_ids = try(identity.value.identity_ids, [])
    }
  }

  app_settings = {
    for s in local.app_settings_list : s.key => s.value
  }

  dynamic "connection_string" {
    for_each = var.connection_string != null ? [var.connection_string] : []
    content {
      name  = connection_string.value.name
      type  = connection_string.value.type
      value = connection_string.value.value
    }
  }

  dynamic "site_config" {
    for_each = [var.site_config]
    content {
      always_on       = lookup(site_config.value, "always_on", null)
      app_scale_limit = lookup(site_config.value, "app_scale_limit", null)

      dynamic "cors" {
        for_each = lookup(site_config.value, "cors", []) != null ? [lookup(site_config.value, "cors", [])] : []
        content {
          allowed_origins     = cors.value.allowed_origins
          support_credentials = lookup(cors.value, "support_credentials", null)
        }
      }
      dotnet_framework_version = lookup(site_config.value, "dotnet_framework_version", null)
      elastic_instance_minimum = lookup(site_config.value, "elastic_instance_minimum", null)
      ftps_state               = lookup(site_config.value, "ftps_state", null)
      health_check_path        = lookup(site_config.value, "health_check_path", null)
      http2_enabled            = lookup(site_config.value, "http2_enabled", null)

      dynamic "ip_restriction" {
        for_each = lookup(site_config.value, "ip_restriction", []) != null ? lookup(site_config.value, "ip_restriction", []) : []
        content {
          ip_address                = lookup(ip_restriction.value, "ip_address", null)
          service_tag               = lookup(ip_restriction.value, "service_tag", null)
          virtual_network_subnet_id = lookup(ip_restriction.value, "virtual_network_subnet_id", null)
          name                      = lookup(ip_restriction.value, "name", null)
          priority                  = lookup(ip_restriction.value, "priority", null)
          action                    = lookup(ip_restriction.value, "action", null)

          dynamic "headers" {
            for_each = length(keys(lookup(ip_restriction.value, "headers", {}))) > 0 ? [lookup(ip_restriction.value, "headers", {})] : []
            content {
              x_azure_fdid      = lookup(headers.value, "x_azure_fdid", [])
              x_fd_health_probe = lookup(headers.value, "x_fd_health_probe", [])
              x_forwarded_for   = lookup(headers.value, "x_forwarded_for", [])
              x_forwarded_host  = lookup(headers.value, "x_forwarded_host", [])
            }
          }
        }
      }
      dynamic "scm_ip_restriction" {
        for_each = lookup(site_config.value, "scm_ip_restriction", []) != null ? lookup(site_config.value, "scm_ip_restriction", []) : []
        content {
          ip_address                = lookup(scm_ip_restriction.value, "ip_address", null)
          service_tag               = lookup(scm_ip_restriction.value, "service_tag", null)
          virtual_network_subnet_id = lookup(scm_ip_restriction.value, "virtual_network_subnet_id", null)
          name                      = lookup(scm_ip_restriction.value, "name", null)
          priority                  = lookup(scm_ip_restriction.value, "priority", null)
          action                    = lookup(scm_ip_restriction.value, "action", null)

          dynamic "headers" {
            for_each = length(keys(lookup(scm_ip_restriction.value, "headers", {}))) > 0 ? [lookup(scm_ip_restriction.value, "headers", {})] : []
            content {
              x_azure_fdid      = lookup(headers.value, "x_azure_fdid", [])
              x_fd_health_probe = lookup(headers.value, "x_fd_health_probe", [])
              x_forwarded_for   = lookup(headers.value, "x_forwarded_for", [])
              x_forwarded_host  = lookup(headers.value, "x_forwarded_host", [])
            }
          }
        }
      }
      scm_use_main_ip_restriction      = lookup(site_config.value, "scm_use_main_ip_restriction", null)
      scm_min_tls_version              = lookup(site_config.value, "scm_min_tls_version", null)
      scm_type                         = lookup(site_config.value, "scm_type", null)
      linux_fx_version                 = lookup(site_config.value, "linux_fx_version", null)
      min_tls_version                  = lookup(site_config.value, "min_tls_version", null)
      pre_warmed_instance_count        = lookup(site_config.value, "pre_warmed_instance_count", null)
      public_network_access_enabled    = lookup(site_config.value, "public_network_access_enabled", null)
      runtime_scale_monitoring_enabled = lookup(site_config.value, "runtime_scale_monitoring_enabled", null)
      use_32_bit_worker_process        = lookup(site_config.value, "use_32_bit_worker_process", null)
      vnet_route_all_enabled           = lookup(site_config.value, "vnet_route_all_enabled", null)
      websockets_enabled               = lookup(site_config.value, "websockets_enabled", null)
    }
  }
  tags = var.tags
}


resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = azurerm_logic_app_standard.this.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_destination_type = each.value.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories
    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.log_groups
    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.metric_categories
    content {
      category = metric.value
    }
  }
}
