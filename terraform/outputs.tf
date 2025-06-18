output "management_node_ip" {
  description = "Public IP address of the BeeGFS management node."
  value       = google_compute_instance.mgnt-node.network_interface[0].access_config[0].nat_ip
}

output "storage_node_ips" {
  description = "Public IP addresses of the BeeGFS storage nodes."
  value       = [for instance in google_compute_instance.storage-nodes : instance.network_interface[0].access_config[0].nat_ip]
}

output "ssh_command_to_mgnt_node" {
  description = "Command to SSH into the management node."
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${google_compute_instance.mgnt-node.network_interface[0].access_config[0].nat_ip}"
}
