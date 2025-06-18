#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -x # Print commands and their arguments as they are executed.

# ---
# common_setup.sh
#
# This script performs the setup common to ALL nodes in the BeeGFS cluster.
# It should be run first on every instance.
#
# Responsibilities:
#   1. Update package lists.
#   2. Install common utilities and Python.
#   3. Add the BeeGFS repository for the correct OS version.
#   4. Install BeeGFS client and utils.
#   5. Install Python ML dependencies from requirements.txt.
#
# This script assumes that the ml/ directory from the repo has been copied to /tmp/ml
# on the remote machine by a Terraform provisioner.
# ---

# 1. Update package lists and install basic dependencies
sudo apt-get update -y
sudo apt-get install -y wget gpg build-essential python3-pip

# 2. Add the BeeGFS repository
# These instructions are for Debian 11 (Bullseye).
# For other OS versions, get the correct URL from:
# https://www.beegfs.io/wiki/InstallationGuide
BEEGFS_REPO_URL="https://www.beegfs.io/release/beegfs_7.3.1/dists/beegfs-bullseye.list"
WGET_URL="https://www.beegfs.io/release/beegfs_7.3.1/gpg/DEB-GPG-KEY-beegfs"

sudo wget -O /etc/apt/sources.list.d/beegfs.list "${BEEGFS_REPO_URL}"
wget "${WGET_URL}"
sudo apt-key add DEB-GPG-KEY-beegfs
rm DEB-GPG-KEY-beegfs
sudo apt-get update -y

# 3. Install BeeGFS client components (needed on all nodes to access the filesystem)
sudo apt-get install -y beegfs-client beegfs-helperd beegfs-utils

# 4. Install Python ML dependencies
# This assumes Terraform's file provisioner has copied the 'ml' dir to /tmp/ml
if [ -f /tmp/ml/requirements.txt ]; then
    sudo pip3 install -r /tmp/ml/requirements.txt
else
    echo "WARNING: /tmp/ml/requirements.txt not found. Skipping ML dependency installation."
fi

echo "Common setup complete."
