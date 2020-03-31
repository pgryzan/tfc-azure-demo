///////////////////////////////////////////////////////////////////////////////////////////////
//  
//  File Name:      hashicorp/main.tf
//  Created By:     Patrick Gryzan, pgryzan@hashicorp.com
//  Date:           03/31/20
//  Comments:       This file defines the terraform actions to perform to create the infrastucture
//  
///////////////////////////////////////////////////////////////////////////////////////////////

//  Set the minimum version of terraform that will work with this code
terraform {
    required_version                = "= 0.12.24"

    backend "remote" {
        organization                = "pgryzan"

        workspaces {
            name                    = "demo"
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
//  Local Variables
///////////////////////////////////////////////////////////////////////////////////////////////
locals {
    name                            = "pgryzan-windows"
    ttl                             = 8
    tags                            = {
        contact                     = "pgryzan@hashicorp.com"
        group                       = "solutions engineering"
        project                     = "demo"
        expires                     = "${timeadd(timestamp(), format("%vh", local.ttl))}"
    }
    tcp_ports                       = ["22", "80", "443", "1433", "5985-5986"]
    tcp_udp_ports                   = ["3389", "9631", "9638"]
}

///////////////////////////////////////////////////////////////////////////////////////////////
//  Import Template Data
///////////////////////////////////////////////////////////////////////////////////////////////
data "template_file" "windows_bootstrap" {
    template                        = "${file("${path.module}/templates/windows_bootstrap.ps1")}"
}

///////////////////////////////////////////////////////////////////////////////////////////////
//  Configuration
///////////////////////////////////////////////////////////////////////////////////////////////
//  Setup the Azure Provider
provider "azurerm" {
    subscription_id                 = var.azure["subscription_id"]
    tenant_id                       = var.azure["tenant_id"]
    client_id                       = var.azure["client_id"]
    client_secret                   = var.azure["client_secret"]
    features {}
}

//  Create a Resource Group
resource "azurerm_resource_group" "azure_rg" {
    name                            = local.name
    location                        = var.azure["region"]
    tags                            = local.tags
}

//  Create a Virtual Network
resource "azurerm_virtual_network" "azure_vnet" {
    name                            = "${local.name}-vnet"
    address_space                   = ["10.0.0.0/16"]
    location                        = var.azure["region"]
    resource_group_name             = azurerm_resource_group.azure_rg.name
    tags                            = merge(local.tags, map("role", "virtual network"))
}

//  Create a Subnet
resource "azurerm_subnet" "azure_subnet" {
    name                            = "${local.name}-subnet"
    resource_group_name             = azurerm_resource_group.azure_rg.name
    virtual_network_name            = azurerm_virtual_network.azure_vnet.name
    address_prefix                  = "10.0.1.0/24"
}

//  Create a Security Group
resource "azurerm_network_security_group" "azure_sg" {
    name                            = "${local.name}-sg"
    location                        = var.azure["region"]
    resource_group_name             = azurerm_resource_group.azure_rg.name
    tags                            = merge(local.tags, map("role", "security group"))
}

//  Create a Rule to Allow All Traffic Out of the Server
resource "azurerm_network_security_rule" "azure_egress" {
    name                            = "tcp_engress"
    priority                        = "1000"
    direction                       = "Outbound"
    access                          = "Allow"
    protocol                        = "*"
    source_port_range               = "*"
    destination_port_range          = "*"
    source_address_prefix           = "*"
    destination_address_prefix      = "*"
    resource_group_name             = azurerm_resource_group.azure_rg.name
    network_security_group_name     = azurerm_network_security_group.azure_sg.name
}

//  Create Rules for Each Defined TCP Port in local.tcp_ports
resource "azurerm_network_security_rule" "azure_tcp_ingress" {
    count                           = length(local.tcp_ports)
    name                            = "tcp_ingress_${replace(element(local.tcp_ports, count.index), "-", "_")}"
    priority                        = 1001 + count.index
    direction                       = "Inbound"
    access                          = "Allow"
    protocol                        = "Tcp"
    source_port_range               = "*"
    destination_port_range          = element(local.tcp_ports, count.index)
    source_address_prefix           = "*"
    destination_address_prefix      = "*"
    resource_group_name             = azurerm_resource_group.azure_rg.name
    network_security_group_name     = azurerm_network_security_group.azure_sg.name
}

//  Create Rules for Each Defined TCP and UDP Port in local.tcp_udp_ports
resource "azurerm_network_security_rule" "azure_tcp_udp_ingress" {
    count                           = length(local.tcp_udp_ports)
    name                            = "udp_ingress_${replace(element(local.tcp_udp_ports, count.index), "-", "_")}"
    priority                        = 1001 + length(local.tcp_ports) + count.index
    direction                       = "Inbound"
    access                          = "Allow"
    protocol                        = "*"
    source_port_range               = "*"
    destination_port_range          = element(local.tcp_udp_ports, count.index)
    source_address_prefix           = "*"
    destination_address_prefix      = "*"
    resource_group_name             = azurerm_resource_group.azure_rg.name
    network_security_group_name     = azurerm_network_security_group.azure_sg.name
}

//  Create a Public IP
resource "azurerm_public_ip" "azure_pip" {
    name                            = "${local.name}-pip"
    location                        = var.azure["region"]
    resource_group_name             = azurerm_resource_group.azure_rg.name
    allocation_method               = "Static"
    tags                            = merge(local.tags, map("role", "public ip"))
}

//  Create a Network Interface
resource "azurerm_network_interface" "azure_nic" {
    name                            = "${local.name}-nic"
    location                        = azurerm_resource_group.azure_rg.location
    resource_group_name             = azurerm_resource_group.azure_rg.name
    tags                            = merge(local.tags, map("role", "network interface"))

    ip_configuration {
        name                            = "${local.name}-ipconfig"
        subnet_id                       = azurerm_subnet.azure_subnet.id
        private_ip_address_allocation   = "dynamic"
        public_ip_address_id            = azurerm_public_ip.azure_pip.id
    }
}

//  Create the Windows VM and Upload the Bootstrap Data
resource "azurerm_virtual_machine" "azure_windows_instance" {
    name                            = "${local.name}-vm"
    location                        = azurerm_resource_group.azure_rg.location
    resource_group_name             = azurerm_resource_group.azure_rg.name
    network_interface_ids           = ["${azurerm_network_interface.azure_nic.id}"]
    vm_size                         = var.instance_type
    tags                            = merge(local.tags, map("role", "vm"))
    delete_os_disk_on_termination   = true

    storage_image_reference {
        offer                       = var.image["offer"]
        publisher                   = var.image["publisher"]
        sku                         = var.image["sku"]
        version                     = var.image["version"]
    }

    storage_os_disk {
        name                        = "${local.name}-disk"
        caching                     = "ReadWrite"
        create_option               = "FromImage"
        managed_disk_type           = "StandardSSD_LRS"
        disk_size_gb                = var.disk_size
    }

    os_profile {
        computer_name               = local.name
        admin_username              = var.windows["username"]
        admin_password              = var.windows["password"]
        custom_data                 = data.template_file.windows_bootstrap.rendered
    }

    os_profile_windows_config {
        provision_vm_agent          = "true"
        enable_automatic_upgrades   = "true"

        winrm {
            protocol                = "http"
            certificate_url         = ""
        }
    }
}

//  Execute the Bootstap with a Azure VM Extension
resource "azurerm_virtual_machine_extension" "azure_extension" {
    name                            = "${local.name}-extension"
    virtual_machine_id             = azurerm_virtual_machine.azure_windows_instance.id
    tags                            = merge(local.tags, map("role", "vm extension"))
    publisher                       = "Microsoft.Compute"
    type                            = "CustomScriptExtension"
    type_handler_version            = "1.9"

    settings = <<SETTINGS
    {
        "commandToExecute" : "powershell -ExecutionPolicy unrestricted -NoProfile -NonInteractive -Command Copy-Item \"c:\\AzureData\\CustomData.bin\" \"c:\\AzureData\\CustomData.ps1\"; \"c:\\AzureData\\CustomData.ps1\""
    }
SETTINGS
}