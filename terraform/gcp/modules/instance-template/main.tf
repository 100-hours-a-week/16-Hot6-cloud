# instance-template module main.tf

resource "google_compute_instance_template" "this" {
  name           = var.name
  machine_type   = var.machine_type

  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
  }

  service_account {
    email  = var.service_account.email
    scopes = var.service_account.scopes
  }

  network_interface {
    subnetwork         = var.subnetwork
  }

  metadata = {
    startup-script   = file(var.startup_script_path)
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}