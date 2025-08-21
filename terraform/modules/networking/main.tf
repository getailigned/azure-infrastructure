# Networking Module - Main Configuration
# Provides Virtual Network, Subnets, Network Security Groups, and Application Gateway

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.resource_group_name}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  
  tags = var.tags
}

# Subnets
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_configs
  
  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
  
  dynamic "service_endpoints" {
    for_each = var.enable_service_endpoints ? (each.value.service_endpoints != null ? each.value.service_endpoints : []) : []
    content {
      service = service_endpoints.value
    }
  }
  
  # Enable private endpoints for data subnets
  private_endpoint_network_policies_enabled = contains(["data", "private-endpoints"], each.key) ? true : false
  
  depends_on = [azurerm_virtual_network.main]
}

# Network Security Groups
resource "azurerm_network_security_group" "nsgs" {
  for_each = var.subnet_configs
  
  name                = "${var.resource_group_name}-${each.key}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = merge(var.tags, {
    Subnet = each.key
  })
}

# NSG Rules for Apps Subnet
resource "azurerm_network_security_rule" "apps_nsg_rules" {
  for_each = {
    "allow-http" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    "allow-https" = {
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    "allow-container-apps" = {
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3000-3010"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
  
  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsgs["apps"].name
}

# NSG Rules for Data Subnet
resource "azurerm_network_security_rule" "data_nsg_rules" {
  for_each = {
    "allow-postgres" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "5432"
      source_address_prefix      = var.vnet_address_space[0]
      destination_address_prefix = "*"
    }
    "allow-redis" = {
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6379"
      source_address_prefix      = var.vnet_address_space[0]
      destination_address_prefix = "*"
    }
    "allow-service-bus" = {
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "5671,5672,443"
      source_address_prefix      = var.vnet_address_space[0]
      destination_address_prefix = "*"
    }
  }
  
  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsgs["data"].name
}

# NSG Rules for Gateway Subnet
resource "azurerm_network_security_rule" "gateway_nsg_rules" {
  for_each = {
    "allow-http" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    "allow-https" = {
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    "allow-application-gateway" = {
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    }
  }
  
  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsgs["gateway"].name
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_associations" {
  for_each = var.subnet_configs
  
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsgs[each.key].id
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "${var.resource_group_name}-appgw-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = var.tags
}

# Route Table for Private Endpoints
resource "azurerm_route_table" "private_endpoints" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${var.resource_group_name}-private-endpoints-rt"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Associate Route Table with Private Endpoints Subnet
resource "azurerm_subnet_route_table_association" "private_endpoints" {
  count = var.enable_private_endpoints ? 1 : 0
  
  subnet_id      = azurerm_subnet.subnets["private-endpoints"].id
  route_table_id = azurerm_route_table.private_endpoints[0].id
}
