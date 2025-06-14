# shared/locals.tf

locals {
  prefix              = "onthetop"
  env_prefix          = "${local.prefix}-${var.env}"
  vpc_name            = "${local.prefix}-vpc"
  public_subnet_name = "${local.prefix}-subnet-${var.env}-public"
  shared_internal_ip_name     = "${local.prefix}-iip-${var.env}-public"
  shared_external_ip_name     = "${local.prefix}-eip-${var.env}-public"
  shared_name        = "${local.prefix}-compute-${var.env}-public"
  router_name        = "${local.prefix}-router-${var.env}"
  cloud_nat_name     = "${local.prefix}-nat-${var.env}"


  raw_firewall_rules = {
    ssh = {
      name          = "ssh"
      port          = ["22"]
      protocols     = ["tcp"] 
      source_ranges = ["0.0.0.0/0"]
      tag_suffix    = "ssh"
    },
    http = {
      name          = "http"
      port          = ["80"]
      protocols     = ["tcp"] 
      source_ranges = ["10.0.0.0/8", "130.211.0.0/22", "35.191.0.0/16"]
      tag_suffix    = "http"
    },
    https = {
      name          = "https"
      port          = ["443"]
      protocols     = ["tcp"] 
      source_ranges = ["10.0.0.0/8"]
      tag_suffix    = "https"
    },
    monitoring-server = {
      name          = "monitoring-server"
      port          = ["3100"]
      protocols     = ["tcp"] 
      source_ranges = ["10.0.0.0/8"]
      tag_suffix    = "monitoring-server"
    },
    vpn = {
      name          = "vpn"
      port          = ["51820"]
      protocols     = ["udp"]
      source_ranges = ["0.0.0.0/0"]
      tag_suffix    = "vpn"
    }
  }

  firewall_expanded_rules = {
    for key, rule in local.raw_firewall_rules : key => {
      name          = "${local.env_prefix}-${rule.name}"
      port          = rule.port
      source_ranges = rule.source_ranges
      protocols     = rule.protocols
      tag           = "${local.env_prefix}-${rule.tag_suffix}"
    }
  }
}