# VPN Gateway Module - Main Configuration
# Provides Point-to-Site VPN Gateway connectivity (disabled by default)

# VPN Gateway Public IP
resource "azurerm_public_ip" "main" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name                = "${var.vpn_gateway_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  # DNS settings
  domain_name_label = "${var.vpn_gateway_name}-${var.environment}-${random_string.suffix.result}"
  
  tags = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "main" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name                = var.vpn_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  
  type     = "Vpn"
  vpn_type = "RouteBased"
  
  # SKU configuration
  sku = var.vpn_gateway_sku
  
  # Generation
  generation = var.vpn_gateway_generation
  
  # IP configuration
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.main[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }
  
  # VPN client configuration
  vpn_client_configuration {
    address_space = [var.vpn_client_address_pool]
    
    vpn_client_protocols = var.vpn_client_protocols
    
    vpn_auth_types = var.vpn_auth_types
    
    # Root certificates
    dynamic "vpn_auth_types" {
      for_each = var.vpn_client_root_certificates
      content {
        name             = vpn_auth_types.key
        public_cert_data = vpn_auth_types.value
      }
    }
  }
  
  # BGP settings (if enabled)
  dynamic "bgp_settings" {
    for_each = var.enable_bgp ? [1] : []
    content {
      asn = var.bgp_asn
    }
  }
  
  tags = var.tags
}

# Network Security Group for VPN Gateway
resource "azurerm_network_security_group" "main" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name                = "${var.vpn_gateway_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# NSG Rules for VPN Gateway
resource "azurerm_network_security_rule" "vpn_gateway" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name                        = "AllowVpnGateway"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.main[0].name
}

resource "azurerm_network_security_rule" "vpn_gateway_udp" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name                        = "AllowVpnGatewayUDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "500"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.main[0].name
}

resource "azurerm_network_security_rule" "vpn_gateway_ike" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name                        = "AllowVpnGatewayIKE"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "4500"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.main[0].name
}

# Route Table for VPN clients
resource "azurerm_route_table" "main" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name                = "${var.vpn_gateway_name}-routes"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  # Disable BGP route propagation
  disable_bgp_route_propagation = false
  
  tags = var.tags
}

# Routes for VPN clients
resource "azurerm_route" "vpn_clients" {
  count = var.enable_vpn_gateway ? length(var.vpn_client_routes) : 0
  
  name                   = "vpn-client-route-${count.index}"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.main[0].name
  address_prefix         = var.vpn_client_routes[count.index].address_prefix
  next_hop_type          = "VirtualNetworkGateway"
  next_hop_in_ip_address = azurerm_virtual_network_gateway.main[0].bgp_settings[0].peering_addresses[0].tunnel_ip_addresses[0]
}

# Associate route table with gateway subnet
resource "azurerm_subnet_route_table_association" "main" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  subnet_id      = var.gateway_subnet_id
  route_table_id = azurerm_route_table.main[0].id
}

# Random string for DNS label
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# VPN Client Configuration
resource "azurerm_vpn_client_configuration" "main" {
  count = var.enable_vpn_gateway ? 1 : 0
  
  name               = "${var.vpn_gateway_name}-client-config"
  resource_group_name = var.resource_group_name
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main[0].id
  
  vpn_client_address_pool {
    address_prefixes = [var.vpn_client_address_pool]
  }
  
  vpn_auth_types = var.vpn_auth_types
  
  vpn_client_protocols = var.vpn_client_protocols
  
  # Root certificates
  dynamic "vpn_client_root_certificate" {
    for_each = var.vpn_client_root_certificates
    content {
      name             = vpn_client_root_certificate.key
      public_cert_data = vpn_client_root_certificate.value
    }
  }
  
  # Revoked certificates (if any)
  dynamic "vpn_client_revoked_certificate" {
    for_each = var.vpn_client_revoked_certificates
    content {
      name       = vpn_client_revoked_certificate.key
      thumbprint = vpn_client_revoked_certificate.value
    }
  }
}
