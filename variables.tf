///////////////////////////////////////////////////////////////////////////////////////////////
//  
//  File Name:      hashicorp/inputs.tf
//  Created By:     Patrick Gryzan, pgryzan@hashicorp.com
//  Date:           03/31/20
//  Comments:       This file defines the terraform input variables
//  
///////////////////////////////////////////////////////////////////////////////////////////////

//  Keys - terraform.tfvars
variable "azure" {
    type            = map
    description     = "The azure provider key information"
}

variable "windows" {
    type            = map
    description     = "The windows setup information"
}

//  VM
variable "instance_type" {
    default         = "Standard_DS2_v2"
    description     = "The size of the vm allocated hardware"
}

variable "disk_size" {
    default         = "100"
    description     = "The vm disk size in GB"
}

variable "image" {
    default         = {
        offer       = "WindowsServer"
        publisher   = "MicrosoftWindowsServer"
        sku         = "2016-Datacenter-smalldisk"
        version     = "latest"
    }
    description     = "The vm image"
}

variable "vm_count" {
    default         = 1
    description     = "The number of VMs we want"
}