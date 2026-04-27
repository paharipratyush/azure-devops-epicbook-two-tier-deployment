variable "location" {
  description = "The Azure Region to deploy resources"
  type        = string
  default     = "South Africa North"
}

variable "vm_size" {
  description = "The size of the Virtual Machine"
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "admin_user" {
  description = "The admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to your local SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "db_user" {
  description = "MySQL Administrator Username"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "MySQL Administrator Password"
  type        = string
  sensitive   = true
}
