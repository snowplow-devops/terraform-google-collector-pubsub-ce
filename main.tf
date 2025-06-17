locals {
  module_name    = "collector-pubsub-ce"
  module_version = "0.6.0"

  app_name    = "stream-collector"
  app_version = var.app_version

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
  version = "0.5.0"

  count = var.telemetry_enabled ? 1 : 0

  user_provided_id = var.user_provided_id
  cloud            = "GCP"
  region           = var.region
  app_name         = local.app_name
  app_version      = local.app_version
  module_name      = local.module_name
  module_version   = local.module_version
}

# --- IAM: Service Account setup

resource "google_service_account" "sa" {
  account_id   = var.name
  display_name = "Snowplow Stream Collector service account - ${var.name}"
}

resource "google_project_iam_member" "sa_pubsub_viewer" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_logging_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# --- CE: Firewall rules

resource "google_compute_firewall" "ingress_ssh" {
  project = (var.network_project_id != "") ? var.network_project_id : var.project_id
  name    = "${var.name}-ssh-in"

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
  project = (var.network_project_id != "") ? var.network_project_id : var.project_id
  name    = "${var.name}-traffic-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["${var.ingress_port}"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

resource "google_compute_firewall" "egress" {
  project = (var.network_project_id != "") ? var.network_project_id : var.project_id
  name    = "${var.name}-traffic-out"

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
    paths           = var.custom_paths
    cookie_domain   = var.cookie_domain
    good_topic_name = var.good_topic_name
    bad_topic_name  = var.bad_topic_name
    project_id      = var.topic_project_id

    byte_limit    = var.byte_limit
    record_limit  = var.record_limit
    time_limit_ms = var.time_limit_ms

    telemetry_disable          = !var.telemetry_enabled
    telemetry_collector_uri    = join("", module.telemetry.*.collector_uri)
    telemetry_collector_port   = 443
    telemetry_secure           = true
    telemetry_user_provided_id = var.user_provided_id
    telemetry_auto_gen_id      = join("", module.telemetry.*.auto_generated_id)
    telemetry_module_name      = local.module_name
    telemetry_module_version   = local.module_version
  })

  startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
    accept_limited_use_license = var.accept_limited_use_license

    port       = var.ingress_port
    config_b64 = base64encode(local.collector_hocon)
    version    = local.app_version

    telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data)

    gcp_logs_enabled = var.gcp_logs_enabled

    java_opts = var.java_opts
  })
}

module "service" {
  source  = "snowplow-devops/service-ce/google"
  version = "0.2.0"

  user_supplied_script        = local.startup_script
  name                        = var.name
  instance_group_version_name = "${local.app_name}-${local.app_version}"
  labels                      = local.labels

  region     = var.region
  network    = var.network
  subnetwork = var.subnetwork

  ubuntu_24_04_source_image   = var.ubuntu_24_04_source_image
  machine_type                = var.machine_type
  target_size                 = var.target_size
  ssh_block_project_keys      = var.ssh_block_project_keys
  ssh_key_pairs               = var.ssh_key_pairs
  service_account_email       = google_service_account.sa.email
  associate_public_ip_address = var.associate_public_ip_address

  named_port_http   = local.named_port_http
  ingress_port      = var.ingress_port
  health_check_path = var.health_check_path

  depends_on = [
    google_compute_firewall.ingress
  ]
}
