#!/bin/bash
# test_run.sh
# This script connects to the first storage node and runs the ML benchmark.

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Starting ML Benchmark Test Run ---"

# Get deployment details from Terraform outputs
GCP_PROJECT_ID=$(terraform output -raw gcp_project_id)
GCP_ZONE=$(terraform output -raw gcp_zone)
# We target the first storage node for the benchmark, as it represents a worker node.
TARGET_NODE_NAME="storage-node-0"

echo "Targeting node: ${TARGET_NODE_NAME} in project ${GCP_PROJECT_ID}, zone ${GCP_ZONE}."
echo ""
echo "Attempting to run ML benchmark on BeeGFS."
echo "This will download CIFAR-10 data to BeeGFS (/mnt/beegfs) on the first run of 'train.py'."
echo "The script is configured to run for 1 epoch for a quick demonstration."
echo "For longer runs, you can manually SSH in and adjust the '--epochs' argument."
echo ""

# Execute the ML training script remotely using gcloud compute ssh.
# The 'ml' directory is copied to /tmp/ml on the remote machine by Terraform.
# The BeeGFS filesystem is mounted at /mnt/beegfs.
gcloud compute ssh "${TARGET_NODE_NAME}" \
  --project "${GCP_PROJECT_ID}" \
  --zone "${GCP_ZONE}" \
  --command "sudo python3 /tmp/ml/train.py --data-path /mnt/beegfs/cifar10 --epochs 1"

echo ""
echo "--- ML Benchmark Execution Status ---"
echo "The ML benchmark execution command has been sent to ${TARGET_NODE_NAME}."
echo "Output should be visible in your terminal above."
echo "To manually SSH into the node and run it again:"
echo "  gcloud compute ssh ${TARGET_NODE_NAME} --zone ${GCP_ZONE}"
echo "Then, inside the VM, run:"
echo "  sudo python3 /tmp/ml/train.py --data-path /mnt/beegfs/cifar10 --epochs 1"
echo ""
