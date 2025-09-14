#!/bin/bash

# Update system packages
yum update -y

# Install EFS utilities
yum install -y amazon-efs-utils

# Create mount directory
mkdir -p /mnt/efs

# Mount EFS file system
echo "${efs_id}.efs.${region}.amazonaws.com:/ /mnt/efs efs defaults,_netdev" >> /etc/fstab
mount -a
