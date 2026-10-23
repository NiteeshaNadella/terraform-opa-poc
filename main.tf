
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-opa-poc"
  location = "canadacentral"

  tags = {
    environment = "dev"
    project     = "opa-poc"
    owner       = "niteesha"
    costcenter  = "IT001"
  }
}



resource "azurerm_storage_account" "example" {
  name                     = "opaniteeshastorage01"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false

  tags = {
    environment = "dev"
    project     = "opa-poc"
    owner       = "niteesha"
    costcenter  = "IT001"
  }
}



# Virtual Network
resource "azurerm_virtual_network" "example" {
  name                = "vnet-opa-poc"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  tags = {
    environment = "dev"
    project     = "opa-poc"
    owner       = "niteesha"
    costcenter  = "IT001"
  }
}

# Subnet
resource "azurerm_subnet" "example" {
  name                 = "subnet-opa-poc"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Interface
resource "azurerm_network_interface" "example" {
  name                = "nic-opa-poc"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "dev"
    project     = "opa-poc"
    owner       = "niteesha"
    costcenter  = "IT001"
  }
}



# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-opa-poc"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  size           = "Standard_B1s"
  admin_username = "azureuser"

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.vm_ssh_public_key
  }

  network_interface_ids = [
    azurerm_network_interface.example.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = "dev"
    project     = "opa-poc"
    owner       = "niteesha"
    costcenter  = "IT001"
  }
}


variable "vm_ssh_public_key" {
  description = "SSH public key for the Linux VM"
  type        = string
}