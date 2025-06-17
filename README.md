# GCP-BeeGFS
Accelerating ML Data Loading with a BeeGFS Parallel Filesystem


How to Deploy This Demo on Google Cloud

Prerequisites:
A Google Cloud Platform (GCP) Account with billing enabled.
Google Cloud SDK installed and configured (gcloud auth login, gcloud config set project YOUR_PROJECT_ID).
Terraform installed.

Deployment Steps:
Clone the repository:
git clone https://github.com/andrepardini/GCP-BeeGFS.git
cd GCP-Beegfs

Initialize Terraform:
cd terraform
terraform init

Deploy the Infrastructure:
terraform apply
(Terraform will show you a plan of the resources it will create. Type yes to approve.) This will take a few minutes.

Connect to a Node and Run the Test:
gcloud compute ssh storage-node1 --zone us-central1-a
(Once inside the VM, follow the original benchmark instructions to run the train.py script).

Clean Up and Destroy All Resources:
IMPORTANT: To avoid incurring GCP costs, destroy all the infrastructure when you are finished.
terraform destroy

(Type yes to approve the destruction of all resources.)




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
└── scripts/                
    ├── common_setup.sh
    ├── mgnt_setup.sh
    └── storage_setup.sh
