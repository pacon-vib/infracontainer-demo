provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  type = string
}

variable "azure_location" {
  type = string
  default = "australiaeast"
}

variable "vnet_name" {
  type = string
}

resource "azurerm_virtual_network" "module" {
  name                = var.vnet_name
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

output "vnet_arm_id" {
  value = azurerm_virtual_network.module.id
}

output "vnet_address_space" {
  value = azurerm_virtual_network.module.address_space
}
