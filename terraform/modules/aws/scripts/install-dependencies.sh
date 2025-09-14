#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y

sudo snap install aws-cli --classic
sudo apt install amazon-ecr-credential-helper -y # AWS ECR Auth Helper