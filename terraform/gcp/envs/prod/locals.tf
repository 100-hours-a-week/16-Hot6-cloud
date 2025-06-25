# prod/locals.tf

locals {
  prefix                      = "onthetop"
  env_prefix                  = "${local.prefix}-${var.env}"
  private_subnet_name         = "${local.prefix}-subnet-${var.env}-private"
  db_primary_subnet_name      = "${local.prefix}-subnet-${var.env}-db-primary"
  db_secondary_subnet_name    = "${local.prefix}-subnet-${var.env}-db-secondary"
  db_primary_ip_name          = "${local.prefix}-iip-${var.env}-db-primary"
  db_secondary_ip_name        = "${local.prefix}-iip-${var.env}-db-secondary"
  db_primary_name             = "${local.prefix}-compute-${var.env}-db-primary"
  db_secondary_name           = "${local.prefix}-compute-${var.env}-db-secondary"

  backend_template_name      = "${local.prefix}-template-${var.env}"
  backend_mig_name           = "${local.prefix}-mig-${var.env}"
  https_lb_name              = "${local.prefix}-hlb-${var.env}"

  raw_firewall_rules = {
    ssh = {
      name          = "ssh"
      port          = ["22"]
      source_ranges = ["0.0.0.0/0"]
      tag_suffix    = "ssh"
    },
    http = {
      name          = "http"
      port          = ["80"]
      source_ranges = ["10.0.0.0/8", "130.211.0.0/22", "35.191.0.0/16"]
      tag_suffix    = "http"
    },
    https = {
      name          = "https"
      port          = ["443"]
      source_ranges = ["10.0.0.0/8"]
      tag_suffix    = "https"
    },
    mysql = {
      name          = "mysql"
      port          = ["3306", "9104"]
      source_ranges = ["10.0.0.0/8"]
      tag_suffix    = "mysql"
    },
    monitoring = {
      name          = "monitoring-targets"
      port          = ["9080", "9100", "9400"]
      source_ranges = ["10.0.0.0/8"]
      tag_suffix    = "monitoring-targets"
    }
    backend = {
      name          = "backend"
      port          = ["8080", "8081"]
      source_ranges = ["10.0.0.0/8", "130.211.0.0/22", "35.191.0.0/16"]
      tag_suffix    = "backend-server"
    }
  }

  firewall_expanded_rules = {
    for key, rule in local.raw_firewall_rules : key => {
      name          = "${local.env_prefix}-${rule.name}"
      port          = rule.port
      source_ranges = rule.source_ranges
      tag           = "${local.env_prefix}-${rule.tag_suffix}"
    }
  }
}
