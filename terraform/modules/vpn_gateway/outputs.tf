# VPN Gateway Module - Outputs

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_virtual_network_gateway.main[0].id : null
}

output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_virtual_network_gateway.main[0].name : null
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_public_ip.main[0].ip_address : null
}

output "vpn_gateway_fqdn" {
  description = "FQDN of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_public_ip.main[0].fqdn : null
}

output "vpn_client_config_url" {
  description = "VPN client configuration URL"
  value       = var.enable_vpn_gateway ? "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/virtualNetworkGateways/${azurerm_virtual_network_gateway.main[0].name}/generatevpnclientpackage?api-version=2023-09-01" : null
}

output "route_table_id" {
  description = "ID of the VPN Gateway route table"
  value       = var.enable_vpn_gateway ? azurerm_route_table.main[0].id : null
}

output "nsg_id" {
  description = "ID of the VPN Gateway Network Security Group"
  value       = var.enable_vpn_gateway ? azurerm_network_security_group.main[0].id : null
}

output "vpn_client_configuration_id" {
  description = "ID of the VPN client configuration"
  value       = var.enable_vpn_gateway ? azurerm_vpn_client_configuration.main[0].id : null
}

# Data source for current client config
data "azurerm_client_config" "current" {}
