#!/bin/bash
sudo usermod -aG docker ubuntu
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh ./get-docker.sh
    rm get-docker.sh
    echo "Docker installation completed."
else
    echo "Docker is already installed. Skipping installation."
fi