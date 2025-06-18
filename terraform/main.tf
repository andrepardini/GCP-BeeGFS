# main.tf

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
    ports    = ["8003", "8004", "8005", "8006", "8008"]
  }
  allow {
    protocol = "udp"
    ports    = ["8003", "8004", "8005", "8006", "8008"]
  }
  # Only allow traffic from within our own subnet
  source_ranges = [google_compute_subnetwork.beegfs_subnet.ip_cidr_range]
}

# Firewall rule to allow SSH from anywhere (for Terraform provisioners)
resource "google_compute_firewall" "allow_ssh" {
  name    = "beegfs-allow-ssh"
  network = google_compute_network.beegfs_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}


# 2. DISKS FOR BEEGFS DATA
# We create separate persistent disks for metadata and storage.
resource "google_compute_disk" "mgnt_meta_disk" {
  name = "mgnt-meta-disk"
  type = "pd-standard"
  size = 20 # GB
}

resource "google_compute_disk" "storage_disks" {
  count = var.storage_node_count
  name  = "storage-data-disk-${count.index}"
  type  = "pd-standard"
  size  = 50 # GB
}


# 3. COMPUTE INSTANCES

# Management Node
resource "google_compute_instance" "mgnt-node" {
  name         = "mgnt-node"
  machine_type = "e2-medium"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Using Debian 11 as specified in scripts
    }
  }

  attached_disk {
    source      = google_compute_disk.mgnt_meta_disk.id
    device_name = "data-disk" # We will mount this as /data
  }

  network_interface {
    subnetwork = google_compute_subnetwork.beegfs_subnet.id
    access_config {} # Assigns an ephemeral public IP
  }

  metadata_startup_script = "sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb && sudo mkdir -p /data && sudo mount -o discard,defaults /dev/sdb /data && sudo chmod a+w /data"

  # Run common setup, then management-specific setup
  provisioner "remote-exec" {
    script = "../scripts/common_setup.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "../scripts/mgnt_setup.sh ${self.name}"
    ]
  }

  # Copy ML files for later use
  provisioner "file" {
    source      = "../ml/"
    destination = "/tmp/ml"
  }
}

# Storage Nodes
resource "google_compute_instance" "storage-nodes" {
  count        = var.storage_node_count
  name         = "storage-node-${count.index}"
  machine_type = "e2-medium"

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
    access_config {}
  }

  metadata_startup_script = "sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb && sudo mkdir -p /data && sudo mount -o discard,defaults /dev/sdb /data && sudo chmod a+w /data"

  # Depend on the management node being created first
  depends_on = [google_compute_instance.mgnt-node]

  # Run common setup, then storage-specific setup
  provisioner "remote-exec" {
    script = "../scripts/common_setup.sh"
  }
  provisioner "remote-exec" {
    inline = [
      # Pass the internal DNS name of the management node
      "../scripts/storage_setup.sh ${google_compute_instance.mgnt-node.name}"
    ]
  }
  
  # Copy ML files
  provisioner "file" {
    source      = "../ml/"
    destination = "/tmp/ml"
  }
}

# 4. FINAL MOUNTING STEP (SOLVES RACE CONDITION)
# This resource doesn't create anything, it just runs provisioners.
# It depends on ALL the storage nodes, so it only runs after they are fully provisioned.

resource "null_resource" "client_mount_all" {
  depends_on = [google_compute_instance.storage-nodes]

  # Mount on the Management Node
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = google_compute_instance.mgnt-node.network_interface[0].access_config[0].nat_ip
  }
  provisioner "remote-exec" {
    inline = [
      "../scripts/client_mount.sh ${google_compute_instance.mgnt-node.name}"
    ]
  }

  # Mount on all Storage Nodes
  # We create one connection/provisioner block for each storage node
  dynamic "connection" {
    for_each = google_compute_instance.storage-nodes
    content {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = connection.for_each.value.network_interface[0].access_config[0].nat_ip
    }
  }
  provisioner "remote-exec" {
    inline = [
      "../scripts/client_mount.sh ${google_compute_instance.mgnt-node.name}"
    ]
  }
}
