# Networking Module - Outputs

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.main.address_space
}

output "subnet_ids" {
  description = "IDs of all subnets"
  value = {
    for k, v in azurerm_subnet.subnets : k => v.id
  }
}

output "subnet_names" {
  description = "Names of all subnets"
  value = {
    for k, v in azurerm_subnet.subnets : k => v.name
  }
}

output "nsg_ids" {
  description = "IDs of all network security groups"
  value = {
    for k, v in azurerm_network_security_group.nsgs : k => v.id
  }
}

output "appgw_public_ip_id" {
  description = "ID of the Application Gateway public IP"
  value       = azurerm_public_ip.appgw.id
}

output "appgw_public_ip_address" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw.ip_address
}

output "route_table_id" {
  description = "ID of the private endpoints route table"
  value       = var.enable_private_endpoints ? azurerm_route_table.private_endpoints[0].id : null
}
