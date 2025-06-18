import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
import torchvision.transforms as transforms

import argparse
import os
import time
from tqdm import tqdm

# Define a simple Convolutional Neural Network
class SimpleCNN(nn.Module):
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv_layer = nn.Sequential(
            nn.Conv2d(in_channels=3, out_channels=32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.Conv2d(in_channels=32, out_channels=64, kernel_size=3, padding=1),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),
            nn.Conv2d(in_channels=64, out_channels=128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),
        )
        self.fc_layer = nn.Sequential(
            nn.Dropout(p=0.1),
            nn.Linear(8 * 8 * 128, 512),
            nn.ReLU(inplace=True),
            nn.Linear(512, 10),
        )

    def forward(self, x):
        x = self.conv_layer(x)
        x = x.view(x.size(0), -1) # Flatten the output for the fully connected layer
        x = self.fc_layer(x)
        return x

def main(args):
    """ Main training and benchmarking function. """
    print("--- ML Training Benchmark ---")
    print(f"Data Path: {args.data_path}")
    print(f"Epochs: {args.epochs}")
    print(f"Batch Size: {args.batch_size}")
    print("-----------------------------\n")

    # Set device (GPU if available, otherwise CPU)
    device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}\n")

    # 1. --- DATA LOADING BENCHMARK ---
    print("Step 1: Loading and preparing data...")
    transform = transforms.Compose(
        [transforms.ToTensor(),
         transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))])

    start_time = time.time()
    
    # The root path is where the data will be downloaded/read from.
    # This is the key variable for our test.
    trainset = torchvision.datasets.CIFAR10(root=args.data_path, train=True,
                                            download=True, transform=transform)
    
    trainloader = torch.utils.data.DataLoader(trainset, batch_size=args.batch_size,
                                              shuffle=True, num_workers=2)
    
    data_load_time = time.time() - start_time
    print(f"Data loading and preparation took: {data_load_time:.2f} seconds\n")

    # 2. --- MODEL TRAINING BENCHMARK ---
    print("Step 2: Initializing model and starting training loop...")
    model = SimpleCNN().to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    # Timing the training loop
    total_training_start_time = time.time()
    
    for epoch in range(args.epochs):
        running_loss = 0.0
        print(f"--- Epoch {epoch + 1}/{args.epochs} ---")
        
        # Use tqdm for a nice progress bar
        for i, data in tqdm(enumerate(trainloader, 0), total=len(trainloader)):
            inputs, labels = data[0].to(device), data[1].to(device)

            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()

    total_training_time = time.time() - total_training_start_time
    print("Training finished.")
    print("-----------------------------\n")
    
    # 3. --- FINAL REPORT ---
    print("--- Benchmark Summary ---")
    print(f"Configuration: Reading from '{args.data_path}'")
    print(f"Data Loading Time: {data_load_time:.4f} seconds")
    print(f"Total Training Time for {args.epochs} epochs: {total_training_time:.4f} seconds")
    print(f"Average Time per Epoch: {total_training_time / args.epochs:.4f} seconds")
    print("-------------------------\n")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="BeeGFS vs Local Disk ML Training Benchmark")
    
    parser.add_argument('--data-path', type=str, required=True,
                        help='Path to the directory where CIFAR-10 data is stored or will be downloaded.')
    
    parser.add_argument('--epochs', type=int, default=2,
                        help='Number of training epochs to run.')
                        
    parser.add_argument('--batch-size', type=int, default=128,
                        help='Batch size for the data loader.')

    args = parser.parse_args()
    
    # Ensure the data directory exists
    os.makedirs(args.data_path, exist_ok=True)
    
    main(args)
