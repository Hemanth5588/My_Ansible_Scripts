 # We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
 terraform {
   required_providers {
     azurerm = {
       source  = "hashicorp/azurerm"
       version = "=4.1.0"
     }
   }
 }

#Variable defining
variable "client_id" {}
variable "tenant_id" {}
variable "client_secret" {}
variable "subscription_id" {}
variable "location" {}
variable "resource_group_name" {}


# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  client_id = var.client_id
  tenant_id = var.tenant_id
  subscription_id = var.subscription_id
  client_secret = var.client_secret
}

 # Create Azure Resource group
resource "azurerm_resource_group" "ansible_project1" {
  location = var.location
  name     = var.resource_group_name
}

# Crate SSH Key
resource "tls_private_key" "ansible_ssh_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

# Create Private Key at local working dir
resource "local_file" "private_key" {
  filename = "${path.module}/id_rsa"
  content = tls_private_key.ansible_ssh_key.private_key_pem
  file_permission = "755"
}

# Create Public Key at local working dir
resource "local_file" "public_key" {
  filename = "${path.module}/id_rsa.pub"
  content = tls_private_key.ansible_ssh_key.public_key_openssh
  file_permission = "755"
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet1" {
  address_space = ["10.0.0.0/28"]
  location            = azurerm_resource_group.ansible_project1.location
  name                = "my_vnet1"
  resource_group_name = azurerm_resource_group.ansible_project1.name
}

# Create Subnetwork
resource "azurerm_subnet" "my_subnet1" {
  address_prefixes = ["10.0.0.0/29"]
  name                 = "my_subnet1"
  resource_group_name  = azurerm_resource_group.ansible_project1.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
}

# Create Public ip address
resource "azurerm_public_ip" "my_public_ip" {
  count = 3
  allocation_method   = "Static"
  location            = azurerm_resource_group.ansible_project1.location
  name                = "my_public_ip-${count.index}"
  resource_group_name = azurerm_resource_group.ansible_project1.name
}

# Create Network Interface controller
resource "azurerm_network_interface" "my_nic" {
  count = 3
  location            = azurerm_resource_group.ansible_project1.location
  name                = "my_nic-${count.index}"
  resource_group_name = azurerm_resource_group.ansible_project1.name
  ip_configuration {
    name                          = "internal"
    subnet_id = azurerm_subnet.my_subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.my_public_ip[count.index].id

  }
}

# Create Azure 3VMs for Ansible infrastructure
resource "azurerm_linux_virtual_machine" "ansible_vms" {
  admin_username      = "azureuser"
  location            = azurerm_resource_group.ansible_project1.location
  name                = "ansible-${count.index}"
  network_interface_ids = [azurerm_network_interface.my_nic[count.index].id]
  resource_group_name = azurerm_resource_group.ansible_project1.name
  size                = "Standard_B1ms"
  count = 3

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ansible_ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "UbuntuServer"
    publisher = "Canonical"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Create Network Security Group
resource "azurerm_network_security_group" "my_nsg" {
  location            = azurerm_resource_group.ansible_project1.location
  name                = "my_nsg"
  resource_group_name = azurerm_resource_group.ansible_project1.name
  security_rule {
    name = "my_rule"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create Network Interface Security Group association
resource "azurerm_network_interface_security_group_association" "my_nisg" {
  count = 3
  network_interface_id      = azurerm_network_interface.my_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.my_nsg.id
}
