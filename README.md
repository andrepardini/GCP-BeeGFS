# GCP-BeeGFS
## Performance Benchmark: Accelerating ML Training with a BeeGFS Parallel Filesystem

This project deploys a BeeGFS parallel filesystem on Google Cloud Platform and demonstrates its use for Machine Learning training by running a simple PyTorch benchmark, showcasing improved data loading performance.

## How to Deploy This Demo on Google Cloud

## Prerequisites:

*   A Google Cloud Platform (GCP) Account with billing enabled.
*   Google Cloud SDK installed and configured (`gcloud auth login`, `gcloud config set project YOUR_PROJECT_ID`).
*   [Terraform](https://developer.hashicorp.com/terraform/downloads) installed.
*   [jq](https://stedolan.github.io/jq/download/) installed (required by `test_run.sh` to parse Terraform output).
*   **Important:** You need to configure your `ssh_user` and `ssh_private_key_path` in `terraform/variables.tf`.
    *   `ssh_user`: This is typically your local username or the username GCP automatically creates on new instances (e.g., for Debian images, it's often your local gcloud username if you have SSH keys configured with gcloud).
    *   `ssh_private_key_path`: The path to the SSH private key associated with your `gcloud` SSH configuration. You can often find it in `~/.ssh/google_compute_engine` or `~/.ssh/id_rsa`.

## Deployment Steps:
1.  Clone the repository:
    ```bash
    git clone https://github.com/andrepardini/GCP-BeeGFS.git
    cd GCP-BeeGFS
    ```

2.  Initialize Terraform:
    ```bash
    cd terraform
    terraform init
    ```

3.  Configure Variables:
    Before deploying, you MUST set your GCP project ID and your SSH user/key path.
    You can do this by creating a `terraform.tfvars` file in the `terraform/` directory:
    ```hcl
    # terraform/terraform.tfvars
    gcp_project_id = "your-gcp-project-id" # REPLACE WITH YOUR GCP PROJECT ID
    ssh_user       = "your-ssh-username"    # REPLACE WITH YOUR SSH USERNAME (e.g., from `whoami`)
    ssh_private_key_path = "/path/to/your/ssh/key" # REPLACE WITH THE ACTUAL PATH TO YOUR SSH PRIVATE KEY
    ```
    Alternatively, you can pass these variables directly on the command line during `terraform apply`.

4.  Deploy the Infrastructure:
    ```bash
    terraform apply
    # (Terraform will show you a plan of the resources it will create. Type 'yes' to approve.)
    ```
    This will take a few minutes (typically 5-10 minutes) as it provisions VMs, sets up BeeGFS services, and copies ML benchmark files.

## Run the ML Benchmark Test:

Once `terraform apply` completes successfully, you can run the ML benchmark. The `test_run.sh` script will connect to the first storage node and execute the `train.py` script. The `train.py` script will automatically download the CIFAR-10 dataset to the BeeGFS filesystem on its first run, making it available to all nodes.

```bash
cd .. # Go back to the root GCP-BeeGFS/ directory
./test_run.sh
```


#File Structure

```
GCP-BeeGFS/
│
├── README.md
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── ml/
│   ├── train.py
│   └── requirements.txt
│
├── scripts/
│   ├── common_setup.sh
│   ├── mgnt_setup.sh
│   ├── storage_setup.sh
│   └── client_mount.sh
│
└── test_run.sh
```
