variable "gcp_project_id" {
  description = "The GCP project ID to deploy resources into."
  type        = string
}

variable "gcp_region" {
  description = "The GCP region to deploy resources into."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "The GCP zone to deploy resources into."
  type        = string
  default     = "us-central1-a"
}

variable "storage_node_count" {
  description = "The number of BeeGFS storage nodes to create."
  type        = number
  default     = 2
}

variable "ssh_user" {
  description = "The username for SSH connections (created by the OS image)."
  type        = string
  # For Debian images, GCP automatically creates a user with the same name as your local user.
  # You might need to adjust this.
}

variable "ssh_private_key_path" {
  description = "The local path to the SSH private key for provisioning."
  type        = string
  # Example: "~/.ssh/gcp_ssh_key"
}
