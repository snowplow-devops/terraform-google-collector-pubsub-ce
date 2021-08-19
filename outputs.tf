output "named_port_http" {
  value       = local.named_port_http
  description = "The name of the port exposed by the instance group"
}

output "named_port_value" {
  value       = var.ingress_port
  description = "The named port value (e.g. 8080)"
}

output "manager_id" {
  value       = google_compute_region_instance_group_manager.grp.id
  description = "Identifier for the instance group manager"
}

output "manager_self_link" {
  value       = google_compute_region_instance_group_manager.grp.self_link
  description = "The URL for the instance group manager"
}

output "instance_group_url" {
  value       = google_compute_region_instance_group_manager.grp.instance_group
  description = "The full URL of the instance group created by the manager"
}

output "health_check_id" {
  value       = google_compute_health_check.hc.id
  description = "Identifier for the health check on the instance group"
}

output "health_check_self_link" {
  value       = google_compute_health_check.hc.self_link
  description = "The URL for the health check on the instance group"
}
