
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  type = string
}

variable "vm_ssh_public_key" {
  type = string
}

locals {
  tags = {
    environment = "dev"
    project     = "dummy-testing"
    owner       = "devops-team"
    costcenter  = "TEST1001"
  }
}

resource "azurerm_resource_group" "demo" {
  name     = "rg-opa-dummy-testing"
  location = "canadacentral"

  tags = local.tags
}

resource "azurerm_virtual_network" "demo" {
  name                = "vnet-opa-dummy-testing"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  address_space       = ["10.80.0.0/16"]
}

resource "azurerm_subnet" "demo" {
  name                 = "subnet-demo"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.80.1.0/24"]
}

resource "azurerm_network_interface" "demo" {
  name                = "nic-opa-dummy-testing"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-opa-dummy-testing"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location

  size           = "Standard_D8s_v5"
  admin_username = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.demo.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.vm_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = local.tags
}
