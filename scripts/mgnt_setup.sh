#!/bin/bash
set -e
set -x

# ---
# mgnt_setup.sh
#
# This script sets up the BeeGFS Management and Metadata services.
# It should ONLY be run on the designated management node.
#
# Responsibilities:
#   1. Install beegfs-mgmtd and beegfs-meta services.
#   2. Create a directory for the metadata service.
#   3. Initialize and configure the services.
#   4. Start and enable the services.
#
# This script assumes a secondary disk is mounted at /data for persistent storage.
# If not, you may need to change the path below to something like /var/beegfs/beegfs_meta.
# ---

# The internal DNS/hostname of the management node, which will be passed
# by Terraform.
BEEGFS_MGMNT_HOST=$1
if [ -z "$BEEGFS_MGMNT_HOST" ]; then
    echo "ERROR: Management host must be provided as the first argument."
    exit 1
fi

# 1. Install BeeGFS management and metadata services
sudo apt-get update -y
sudo apt-get install -y beegfs-mgmtd beegfs-meta

# 2. Create directory for metadata storage
# Using /data/beegfs_meta assumes a dedicated persistent disk is mounted at /data
META_DIR="/data/beegfs_meta"
sudo mkdir -p "${META_DIR}"
sudo chown beegfs:beegfs "${META_DIR}"

# 3. Initialize services
# The management service stores its data in /var/lib/beegfs/beegfs-mgmtd by default
sudo /opt/beegfs/sbin/beegfs-setup-mgmtd -p "${META_DIR}"
# The metadata service needs to know where its data lives and which management daemon to register with
sudo /opt/beegfs/sbin/beegfs-setup-meta -p "${META_DIR}" -s 2 -m "${BEEGFS_MGMNT_HOST}"

# 4. Start and enable services
sudo systemctl start beegfs-mgmtd beegfs-meta
sudo systemctl enable beegfs-mgmtd beegfs-meta

echo "Management node setup complete."
