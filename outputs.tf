///////////////////////////////////////////////////////////////////////////////////////////////
//  
//  File Name:      hashicorp/outputs.tf
//  Created By:     Patrick Gryzan, pgryzan@hashicorp.com
//  Date:           03/31/20
//  Comments:       This file defines the terraform output variables
//  
///////////////////////////////////////////////////////////////////////////////////////////////

output "windows" {
    value           = {
        ip          = "${azurerm_public_ip.azure_pip.ip_address}"
    }
}