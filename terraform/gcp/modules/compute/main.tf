# compute module main.tf

resource "google_compute_instance" "vm" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone != null ? var.zone : "asia-northeast3-a"
  tags         = var.tags

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = var.subnetwork

    network_ip = var.internal_ip

    dynamic "access_config" {
      for_each = var.external_ip != null ? [1] : []
      content {
        nat_ip = var.external_ip
      }
    }
  }

  metadata = {
    enable-oslogin           = "FALSE"
    google-logging-enabled   = "FALSE"
    google-monitoring-enabled = "FALSE"
    ssh-keys                 = var.ssh_keys
  }
}
