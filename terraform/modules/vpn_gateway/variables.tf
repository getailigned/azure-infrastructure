# VPN Gateway Module - Variables

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  type        = string
}

variable "gateway_subnet_id" {
  description = "ID of the gateway subnet"
  type        = string
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway (disabled by default)"
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "VPN Gateway SKU"
  type        = string
  default     = "VpnGw1"
  
  validation {
    condition     = contains(["VpnGw1", "VpnGw2", "VpnGw3", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ"], var.vpn_gateway_sku)
    error_message = "VPN Gateway SKU must be one of: VpnGw1, VpnGw2, VpnGw3, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ."
  }
}

variable "vpn_gateway_generation" {
  description = "VPN Gateway generation"
  type        = string
  default     = "Generation2"
  
  validation {
    condition     = contains(["Generation1", "Generation2"], var.vpn_gateway_generation)
    error_message = "VPN Gateway generation must be either Generation1 or Generation2."
  }
}

variable "vpn_client_address_pool" {
  description = "VPN client address pool CIDR"
  type        = string
  default     = "172.16.0.0/24"
}

variable "vpn_client_protocols" {
  description = "VPN client protocols"
  type        = list(string)
  default     = ["OpenVPN"]
  
  validation {
    condition     = alltrue([for protocol in var.vpn_client_protocols : contains(["OpenVPN", "IkeV2"], protocol)])
    error_message = "VPN client protocols must be OpenVPN and/or IkeV2."
  }
}

variable "vpn_auth_types" {
  description = "VPN authentication types"
  type        = list(string)
  default     = ["Certificate"]
  
  validation {
    condition     = alltrue([for auth_type in var.vpn_auth_types : contains(["Certificate", "AAD", "Radius"], auth_type)])
    error_message = "VPN authentication types must be Certificate, AAD, and/or Radius."
  }
}

variable "vpn_client_root_certificates" {
  description = "VPN client root certificates"
  type        = map(string)
  default     = {}
}

variable "vpn_client_revoked_certificates" {
  description = "VPN client revoked certificates"
  type        = map(string)
  default     = {}
}

variable "vpn_client_routes" {
  description = "VPN client routes"
  type = list(object({
    address_prefix = string
    description    = optional(string)
  }))
  default = []
}

variable "enable_bgp" {
  description = "Enable BGP for VPN Gateway"
  type        = bool
  default     = false
}

variable "bgp_asn" {
  description = "BGP ASN for VPN Gateway"
  type        = number
  default     = 65515
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
