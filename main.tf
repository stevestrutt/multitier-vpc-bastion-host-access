
# provider block required with Schematics to set VPC region
provider "ibm" {
  region = var.ibm_region
  #ibmcloud_api_key = var.ibmcloud_api_key
  generation = local.generation
  version    = ">= 1.4"
}

data "ibm_resource_group" "all_rg" {
  name = var.resource_group_name
}

locals {
  generation     = 2
  frontend_count = 2
  backend_count  = 1
}


##################################################################################################
#  Select CIDRs allowed to access bastion host  
#  When running under Schematics allowed ingress CIDRs are set to only allow access from Schematics  
#  for use with Remote-exec and Redhat Ansible
#  When running under Terraform local execution ingress is set to 0.0.0.0/0
#  Access CIDRs are overridden if user_bastion_ingress_cidr is set to anything other than "0.0.0.0/0" 
##################################################################################################


data "external" "env" { program = ["jq", "-n", "env"] }
locals {
  region = lookup(data.external.env.result, "TF_VAR_SCHEMATICSLOCATION", "")
  geo    = substr(local.region, 0, 2)
  schematics_ssh_access_map = {
    us = ["169.44.0.0/14", "169.60.0.0/14"],
    eu = ["158.175.0.0/16","158.176.0.0/15","141.125.75.80/28","161.156.139.192/28","149.81.103.128/28"],
  }
  schematics_ssh_access = lookup(local.schematics_ssh_access_map, local.geo, ["0.0.0.0/0"])
  bastion_ingress_cidr  = var.ssh_source_cidr_override[0] != "0.0.0.0/0" ? var.ssh_source_cidr_override : local.schematics_ssh_access
}




locals {
  # bastion_cidr_blocks  = [cidrsubnet(var.bastion_cidr, 4, 0), cidrsubnet(var.bastion_cidr, 4, 2), cidrsubnet(var.bastion_cidr, 4, 4)]
  frontend_cidr_blocks = [cidrsubnet(var.frontend_cidr, 4, 0), cidrsubnet(var.frontend_cidr, 4, 2), cidrsubnet(var.frontend_cidr, 4, 4)]
  backend_cidr_blocks  = [cidrsubnet(var.backend_cidr, 4, 0), cidrsubnet(var.backend_cidr, 4, 2), cidrsubnet(var.backend_cidr, 4, 4)]
}


module "accesscheck" {
  source          = "./accesscheck"
  ssh_accesscheck = var.ssh_accesscheck
  ssh_private_key = var.ssh_private_key
  bastion_host    = var.bastion_ip_address
  target_hosts    = [var.host_ip_addresses] 
      #concat(module.bastion.bastion_ip_addresses[0], module.frontend.primary_ipv4_address, module.backend.primary_ipv4_address)
}
