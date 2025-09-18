output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = yandex_compute_instance.url-shortener-vm.network_interface[0].nat_ip_address
}

output "database_host" {
  description = "PostgreSQL database host"
  value       = yandex_mdb_postgresql_cluster.url-shortener-db.host[0].fqdn
}

output "application_url" {
  description = "URL of the application"
  value       = "http://${yandex_compute_instance.url-shortener-vm.network_interface[0].nat_ip_address}"
}

output "ssh_connection_command" {
  description = "Command to SSH into the VM"
  value       = "ssh -i ~/.ssh/id_ed25519_terraform ${var.vm_username}@${yandex_compute_instance.url-shortener-vm.network_interface[0].nat_ip_address}"
}