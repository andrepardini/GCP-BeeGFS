#!/bin/bash
set -e
set -x

# ---
# client_mount.sh
#
# This script sets up the BeeGFS client and mounts the BeeGFS filesystem.
# It should be run on all nodes that need to access the BeeGFS filesystem.
#
# Responsibilities:
#   1. Configure the BeeGFS client to point to the management daemon.
#   2. Ensure the BeeGFS client service is running and correctly mounted.
# ---

# The internal DNS/hostname of the management node, which will be passed
# by Terraform.
BEEGFS_MGMNT_HOST=$1
if [ -z "$BEEGFS_MGMNT_HOST" ]; then
    echo "ERROR: Management host must be provided as the first argument."
    exit 1
fi

# Mount point for BeeGFS
MOUNT_POINT="/mnt/beegfs"
sudo mkdir -p "${MOUNT_POINT}" || { echo "Failed to create mount point ${MOUNT_POINT}"; exit 1; }

# Configure BeeGFS client to point to the management daemon
# This updates /etc/beegfs/beegfs-client.conf
sudo sed -i "s/^#sysMgmtdHost=.*/sysMgmtdHost=${BEEGFS_MGMNT_HOST}/" /etc/beegfs/beegfs-client.conf

# Restart client service to pick up config change and trigger auto-mount
echo "Restarting beegfs-client service..."
sudo systemctl restart beegfs-client || { echo "Failed to restart beegfs-client service. Exiting."; exit 1; }

# Give it a moment to mount
sleep 5

# Verify mount
if mountpoint -q "${MOUNT_POINT}"; then
  echo "BeeGFS mounted successfully at ${MOUNT_POINT}."
else
  echo "Failed to auto-mount BeeGFS at ${MOUNT_POINT}. Attempting manual mount..."
  # Manual mount attempt if restart didn't automatically mount it
  # Assuming default filesystem name /beegfs
  sudo /opt/beegfs/sbin/mount.beegfs "${BEEGFS_MGMNT_HOST}:/beegfs" "${MOUNT_POINT}" || { echo "Manual mount failed. Please check logs."; exit 1; }
  if mountpoint -q "${MOUNT_POINT}"; then
    echo "BeeGFS manually mounted successfully."
  else
    echo "Severe error: BeeGFS could not be mounted. Check 'sudo dmesg | grep beegfs' and 'sudo systemctl status beegfs-client'."
    exit 1
  fi
fi

# Optional: Ensure everyone can write to the mount point for demo purposes
sudo chmod a+rwx "${MOUNT_POINT}"

echo "BeeGFS client mount setup complete."
