terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.50.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# 1. NETWORKING
# A VPC network for our cluster to communicate on
resource "google_compute_network" "beegfs_vpc" {
  name                    = "beegfs-vpc"
  auto_create_subnetworks = false
}

# A subnet within the VPC
resource "google_compute_subnetwork" "beegfs_subnet" {
  name          = "beegfs-subnet"
  ip_cidr_range = "10.10.1.0/24"
  network       = google_compute_network.beegfs_vpc.id
  region        = var.gcp_region
}

# Firewall rule to allow BeeGFS traffic within our VPC
resource "google_compute_firewall" "beegfs_internal" {
  name    = "beegfs-internal-allow"
  network = google_compute_network.beegfs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8003", "8004", "8005", "8006", "8008"] # Common BeeGFS ports
  }
  allow {
    protocol = "udp"
    ports    = ["8003", "8004", "8005", "8006", "8008"] # Common BeeGFS ports
  }
  # Only allow traffic from within our own subnet
  source_ranges = [google_compute_subnetwork.beegfs_subnet.ip_cidr_range]
}

# Firewall rule to allow SSH from anywhere (for Terraform provisioners and user access)
resource "google_compute_firewall" "allow_ssh" {
  name    = "beegfs-allow-ssh"
  network = google_compute_network.beegfs_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # Be cautious in production, restrict to known IPs.
}


# 2. DISKS FOR BEEGFS DATA
# We create separate persistent disks for metadata and storage.
resource "google_compute_disk" "mgnt_meta_disk" {
  name = "mgnt-meta-disk"
  type = "pd-standard"
  size = 20 # GB - Adequate for meta and mgmtd data for a small test.
  zone = var.gcp_zone # Must be in the same zone as the instance
}

resource "google_compute_disk" "storage_disks" {
  count = var.storage_node_count
  name  = "storage-data-disk-${count.index}"
  type  = "pd-standard"
  size  = 50 # GB - Adequate for CIFAR-10 and some overflow.
  zone  = var.gcp_zone # Must be in the same zone as the instance
}


# 3. COMPUTE INSTANCES

# Management Node (also hosts Metadata service)
resource "google_compute_instance" "mgnt-node" {
  name         = "mgnt-node"
  machine_type = "e2-medium" # Default machine type for test

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Using Debian 11 for consistency with BeeGFS repo
    }
  }

  attached_disk {
    source      = google_compute_disk.mgnt_meta_disk.id
    device_name = "data-disk" # We will mount this as /data
  }

  network_interface {
    subnetwork = google_compute_subnetwork.beegfs_subnet.id
    # Assigns an ephemeral public IP for SSH access during provisioning and for user.
    access_config {}
    network_ip = "10.10.1.10" # Static internal IP for easy reference
  }

  # Startup script to format and mount the attached persistent disk
  metadata_startup_script = <<-EOT
    sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
    sudo mkdir -p /data
    sudo mount -o discard,defaults /dev/sdb /data
    sudo chmod a+w /data # Allow all users to write for demo simplicity
  EOT

  # Provisioners to run necessary setup scripts
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
    script = "../scripts/common_setup.sh"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
    inline = [
      # Pass the internal DNS name of the management node to the setup script
      "../scripts/mgnt_setup.sh ${self.name}"
    ]
  }

  # Copy ML files for later use by the benchmark
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
    source      = "../ml/"
    destination = "/tmp/ml"
  }
}

# Storage Nodes
resource "google_compute_instance" "storage-nodes" {
  count        = var.storage_node_count
  name         = "storage-node-${count.index}"
  machine_type = "e2-medium" # Default machine type for test

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  attached_disk {
    source      = google_compute_disk.storage_disks[count.index].id
    device_name = "data-disk"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.beegfs_subnet.id
    access_config {} # Assigns an ephemeral public IP
    network_ip = "10.10.1.${20 + count.index}" # Static internal IP for easy reference
  }

  # Startup script to format and mount the attached persistent disk
  metadata_startup_script = <<-EOT
    sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
    sudo mkdir -p /data
    sudo mount -o discard,defaults /dev/sdb /data
    sudo chmod a+w /data # Allow all users to write for demo simplicity
  EOT

  # Ensure the management node is created and its services are attempting to start before storage nodes try to connect.
  depends_on = [google_compute_instance.mgnt-node]

  # Provisioners to run necessary setup scripts
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
    script = "../scripts/common_setup.sh"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
    inline = [
      # Pass the internal DNS name of the management node and a unique target ID
      # to the storage setup script. Target IDs must be unique across all storage targets.
      "../scripts/storage_setup.sh ${google_compute_instance.mgnt-node.name} ${100 + count.index}"
    ]
  }

  # Copy ML files for later use by the benchmark
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
    source      = "../ml/"
    destination = "/tmp/ml"
  }
}

# 4. FINAL MOUNTING STEP (SOLVES RACE CONDITION)
# This null_resource doesn't create GCP resources but waits for
# ALL storage nodes to be provisioned and then idempotently runs
# the client mount script on all nodes. This helps to ensure BeeGFS
# is fully operational before any ML training attempts to use it.

resource "null_resource" "client_mount_all" {
  # This depends on ALL storage nodes being fully provisioned.
  # This makes it one of the last steps performed.
  depends_on = [google_compute_instance.storage-nodes]

  # Mount on the Management Node
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = google_compute_instance.mgnt-node.network_interface[0].access_config[0].nat_ip
    }
    # Pass the management node's internal DNS name to the client mount script
    script = "../scripts/client_mount.sh ${google_compute_instance.mgnt-node.name}"
  }

  # Mount on all Storage Nodes
  # The dynamic block creates a separate connection and provisioner for each storage node
  dynamic "provisioner" {
    for_each = google_compute_instance.storage-nodes
    content {
      remote-exec {
        connection {
          type        = "ssh"
          user        = var.ssh_user
          private_key = file(var.ssh_private_key_path)
          host        = provisioner.for_each.value.network_interface[0].access_config[0].nat_ip
        }
        # Pass the management node's internal DNS name to the client mount script
        script = "../scripts/client_mount.sh ${google_compute_instance.mgnt-node.name}"
      }
    }
  }
}

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

output "gcp_project_id" {
  description = "The GCP project ID used for deployment."
  value       = var.gcp_project_id
}

output "gcp_zone" {
  description = "The GCP zone used for deployment."
  value       = var.gcp_zone
}

output "ssh_user" {
  description = "The username used for SSH connections (for test_run.sh)."
  value       = var.ssh_user
}

output "ssh_private_key_path" {
  description = "The local path to the SSH private key (for test_run.sh)."
  value       = var.ssh_private_key_path
}
