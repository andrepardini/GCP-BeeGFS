#!/bin/bash
set -e
set -x

# ---
# storage_setup.sh
#
# This script sets up a BeeGFS Storage service.
# It should be run on all designated storage nodes.
#
# Responsibilities:
#   1. Install beegfs-storage service.
#   2. Create a directory for the storage target.
#   3. Initialize the service, pointing it to the management node.
#   4. Start and enable the service.
#
# This script assumes a secondary disk is mounted at /data for persistent storage.
# ---

# The internal DNS/hostname of the management node, which will be passed
# by Terraform as the first argument.
BEEGFS_MGMNT_HOST=$1
if [ -z "$BEEGFS_MGMNT_HOST" ]; then
    echo "ERROR: Management host must be provided as the first argument."
    exit 1
fi

# 1. Install BeeGFS storage service
sudo apt-get update -y
sudo apt-get install -y beegfs-storage

# 2. Create directory for the storage target
# Using /data/beegfs_storage assumes a dedicated persistent disk is mounted at /data
STORAGE_DIR="/data/beegfs_storage"
sudo mkdir -p "${STORAGE_DIR}"
sudo chown beegfs:beegfs "${STORAGE_DIR}"

# 3. Initialize the storage service
# It needs to know where its data lives (-p) and which management daemon to register with (-m)
sudo /opt/beegfs/sbin/beegfs-setup-storage -p "${STORAGE_DIR}" -s 3 -i 101 -m "${BEEGFS_MGMNT_HOST}"

# 4. Start and enable the service
sudo systemctl start beegfs-storage
sudo systemctl enable beegfs-storage

# 5. Final step: Configure and mount the client on all nodes
# This command needs to run on ALL nodes (mgnt, storage) AFTER all daemons are running.
# It's often best to run this as a final, separate provisioner step in Terraform.
sudo mkdir -p /mnt/beegfs
sudo /opt/beegfs/sbin/beegfs-setup-client -m "${BEEGFS_MGMNT_HOST}"
# beegfs-setup-client auto-generates /etc/beegfs/beegfs-client.conf
# And then we mount it:
sudo mount -t beegfs beegfs_nodev /mnt/beegfs

# To make the mount persistent, add to /etc/fstab
echo "beegfs_nodev /mnt/beegfs beegfs defaults,cfgFile=/etc/beegfs/beegfs-client.conf 0 0" | sudo tee -a /etc/fstab

echo "Storage node setup and client mount complete."
