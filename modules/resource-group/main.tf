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

resource "azurerm_resource_group" "module" {
  name     = var.resource_group_name
  location = var.azure_location
}

output "resource_group_name" {
  value = azurerm_resource_group.module.name
}

output "resource_group_location" {
  value = azurerm_resource_group.module.location
}
