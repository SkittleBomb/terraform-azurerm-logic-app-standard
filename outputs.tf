output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_logic_app_standard.this
}

output "resource_id" {
  description = "This is the full output for the resource."
  value       = azurerm_logic_app_standard.this.id
}
