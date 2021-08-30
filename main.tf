locals {
  module_name    = "collector-pubsub-ce"
  module_version = "0.2.0"

  app_name    = "stream-collector"
  app_version = "2.3.1"

  local_labels = {
    name           = var.name
    app_name       = local.app_name
    app_version    = replace(local.app_version, ".", "-")
    module_name    = local.module_name
    module_version = replace(local.module_version, ".", "-")
  }

  labels = merge(
    var.labels,
    local.local_labels
  )

  named_port_http = "http"
}

module "telemetry" {
  source  = "snowplow-devops/telemetry/snowplow"
  version = "0.2.0"

  count = var.telemetry_enabled ? 1 : 0

  user_provided_id = var.user_provided_id
  cloud            = "GCP"
  region           = var.region
  app_name         = local.app_name
  app_version      = local.app_version
  module_name      = local.module_name
  module_version   = local.module_version
}

data "google_compute_image" "ubuntu_20_04" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

# --- IAM: Service Account setup

resource "google_service_account" "sa" {
  account_id   = var.name
  display_name = "Snowplow Stream Collector service account - ${var.name}"
}

resource "google_project_iam_member" "sa_pubsub_viewer" {
  role   = "roles/pubsub.viewer"
  member = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_pubsub_publisher" {
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_logging_log_writer" {
  role   = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.sa.email}"
}

# --- CE: Firewall rules

resource "google_compute_firewall" "ingress_ssh" {
  name = "${var.name}-ssh-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_ip_allowlist
}

# Needed to allow Health Checks and External Load Balancing services access to
# our server group.
#
# https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
resource "google_compute_firewall" "ingress" {
  name = "${var.name}-traffic-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["${var.ingress_port}"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

resource "google_compute_firewall" "egress" {
  name = "${var.name}-traffic-out"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["123"]
  }

  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
}

# --- CE: Instance group setup

locals {
  collector_hocon = templatefile("${path.module}/templates/config.hocon.tmpl", {
    port            = var.ingress_port
    cookie_domain   = var.cookie_domain
    good_topic_name = var.good_topic_name
    bad_topic_name  = var.bad_topic_name
    project_id      = var.topic_project_id

    byte_limit    = var.byte_limit
    record_limit  = var.record_limit
    time_limit_ms = var.time_limit_ms
  })

  startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
    port    = var.ingress_port
    config  = local.collector_hocon
    version = local.app_version

    telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data)

    gcp_logs_enabled = var.gcp_logs_enabled
  })

  ssh_keys_metadata = <<EOF
%{for v in var.ssh_key_pairs~}
    ${v.user_name}:${v.public_key}
%{endfor~}
EOF
}

resource "google_compute_instance_template" "tpl" {
  name_prefix = "${var.name}-"
  description = "This template is used to create Stream Collector instances"

  instance_description = var.name
  machine_type         = var.machine_type

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = var.ubuntu_20_04_source_image == "" ? data.google_compute_image.ubuntu_20_04.self_link : var.ubuntu_20_04_source_image
    auto_delete  = true
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 10
  }

  # Note: Only one of either network or subnetwork can be supplied
  #       https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template#network_interface
  network_interface {
    network    = var.subnetwork == "" ? var.network : ""
    subnetwork = var.subnetwork

    dynamic "access_config" {
      for_each = var.associate_public_ip_address ? [1] : []

      content {
        network_tier = "PREMIUM"
      }
    }
  }

  service_account {
    email  = google_service_account.sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = local.startup_script

  metadata = {
    block-project-ssh-keys = var.ssh_block_project_keys

    ssh-keys = local.ssh_keys_metadata
  }

  tags = [var.name]

  labels = local.labels

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "hc" {
  name = var.name

  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10

  http_health_check {
    request_path = var.health_check_path
    port         = var.ingress_port
  }
}

resource "google_compute_region_instance_group_manager" "grp" {
  name = "${var.name}-grp"

  base_instance_name = var.name
  region             = var.region

  target_size = var.target_size

  named_port {
    name = local.named_port_http
    port = var.ingress_port
  }

  version {
    name              = "${local.app_name}-${local.app_version}"
    instance_template = google_compute_instance_template.tpl.self_link
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_unavailable_fixed = 3
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.hc.self_link
    initial_delay_sec = 300
  }

  wait_for_instances = true

  timeouts {
    create = "20m"
    update = "20m"
    delete = "30m"
  }

  depends_on = [
    google_compute_firewall.ingress
  ]
}
