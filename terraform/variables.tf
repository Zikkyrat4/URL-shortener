variable "yandex_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yandex_folder_id" {
  description = "Yandex Folder ID"
  type        = string
}

variable "yandex_token" {
  description = "Yandex OAuth token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "db_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "app_user"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "vm_username" {
  description = "VM username"
  type        = string
  default     = "ubuntu"
}