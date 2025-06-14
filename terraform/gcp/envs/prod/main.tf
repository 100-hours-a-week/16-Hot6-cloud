# prod/main.tf

data "google_compute_network" "vpc" {
  name                = "onthetop-vpc"
}

module "subnet_private" {
  source   = "../../modules/subnet"
  name     = local.private_subnet_name
  region   = var.region
  cidr     = var.private_subnet_cidr
  network  = data.google_compute_network.vpc.id
}

module "subnet_db_primary" {
  source   = "../../modules/subnet"
  name     = local.db_primary_subnet_name
  region   = var.region
  cidr     = var.db_primary_subnet_cidr
  network  = data.google_compute_network.vpc.id
}

module "subnet_db_secondary" {
  source   = "../../modules/subnet"
  name     = local.db_secondary_subnet_name
  region   = var.region
  cidr     = var.db_secondary_subnet_cidr
  network  = data.google_compute_network.vpc.id
}

module "db_primary_internal_ip" {
  source     = "../../modules/ip-internal"
  name       = local.db_primary_ip_name
  region     = var.region
  project_id = var.project_id
  subnetwork = module.subnet_db_primary.self_link
}

module "db_secondary_internal_ip" {
  source     = "../../modules/ip-internal"
  name       = local.db_secondary_ip_name
  region     = var.region
  project_id = var.project_id
  subnetwork = module.subnet_db_secondary.self_link
}

module "db_primary_instance" {
  source       = "../../modules/compute"
  name         = local.db_primary_name
  region       = var.region
  machine_type = var.db_machine_type
  image        = var.db_image
  subnetwork   = module.subnet_db_primary.self_link
  internal_ip  = module.db_primary_internal_ip.address
  ssh_keys     = var.ssh_keys
  tags         = [
    for name in ["ssh", "mysql", "monitoring"] : local.firewall_expanded_rules[name].tag
  ]
}

module "db_secondary_instance" {
  source       = "../../modules/compute"
  name         = local.db_secondary_name
  region       = var.region
  machine_type = var.db_machine_type
  image        = var.db_image
  subnetwork   = module.subnet_db_secondary.self_link
  internal_ip  = module.db_secondary_internal_ip.address
  ssh_keys     = var.ssh_keys
  tags         = [
    for name in ["ssh", "mysql", "monitoring"] : local.firewall_expanded_rules[name].tag
  ]
}

resource "random_string" "template_suffix" {
  length  = 6
  special = false
  upper   = false

  keepers = {
    startup_script_hash = filesha256("../../../../scripts/cicd/docker-startup-script.sh")
    image               = var.backend_image
    machine_type        = var.backend_machine_type
  }
}

module "backend_template" {
  source         = "../../modules/instance-template"
  name           = "${local.backend_template_name}-${random_string.template_suffix.result}"
  machine_type   = var.backend_machine_type
  image          = var.backend_image
  subnetwork     = module.subnet_private.self_link
  startup_script_path = "../../../../scripts/cicd/docker-startup-script.sh"
  service_account = {
    email  = "onthetop-sa-secret-manager@onlinevoting-378808.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
    }
  tags = [
    for name in ["ssh", "http", "https", "monitoring", "backend"] : local.firewall_expanded_rules[name].tag
  ]
}

module "backend_health_check" {
  source      = "../../modules/health-check"
  name        = "backend-health-check"
  project_id  = var.project_id
  protocol    = "HTTP"
  port        = 80
  request_path = "/api/v1/health"
}

module "backend_mig" {
  source             = "../../modules/mig"
  name               = local.backend_mig_name
  project_id         = var.project_id
  region             = var.region
  instance_template  = module.backend_template.template_self_link
  target_size        = 1
  named_port         = "http"
  port               = 80
  health_check       = module.backend_health_check.self_link # 없으면 null
  update_policy = {
    type                   = "PROACTIVE"
    minimal_action         = "REPLACE"
    replacement_method     = "SUBSTITUTE"
    max_surge_fixed        = 3
    max_unavailable_fixed  = 0
  }
}

resource "google_certificate_manager_dns_authorization" "wildcard_auth" {
  name   = "dns-authz-onthe-top-com"
  domain = "onthe-top.com"
}

resource "google_certificate_manager_certificate" "wildcard_cert" {
  name     = "wildcard-cert-onthe-top"
  location = "global"

  managed {
    domains            = ["*.onthe-top.com"]
    dns_authorizations = [google_certificate_manager_dns_authorization.wildcard_auth.id]
  }
}

resource "google_certificate_manager_certificate_map" "default" {
  name = "onthetop-cert-map"
}

resource "google_certificate_manager_certificate_map_entry" "wildcard_entry" {
  name         = "wildcard-entry"
  map          = google_certificate_manager_certificate_map.default.name
  hostname     = "*.onthe-top.com"
  certificates = [google_certificate_manager_certificate.wildcard_cert.id]
}

module "https_lb" {
  source           = "../../modules/https-lb"
  name             = local.https_lb_name
  certificate_map = "//certificatemanager.googleapis.com/projects/${var.project_id}/locations/global/certificateMaps/${google_certificate_manager_certificate_map.default.name}"
  instance_group   = module.backend_mig.instance_group
  health_check     = module.backend_health_check.self_link
}

module "firewall" {
  for_each    = local.firewall_expanded_rules
  source      = "../../modules/firewall"
  name        = each.value.name
  port        = each.value.port
  source_ranges = each.value.source_ranges
  target_tag  = each.value.tag
  network  = data.google_compute_network.vpc.id
}