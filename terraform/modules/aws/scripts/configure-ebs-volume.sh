#!/bin/bash
parents="$(lsblk -rpno PKNAME | awk '$1{if ($1 ~ /^\//) print $1; else print "/dev/"$1}' | sort -u)"
while IFS= read -r line; do
    read -r -a parts <<< "$line"
    name=${parts[0]}
    fstype=${parts[1]}
    mountpoint=${parts[2]}

    # skip whole-disk devices that have partitions
    if printf '%s\n' "$parents" | grep -xFq "$name"; then
        echo "Skipping $name (has partitions)" >&2
        continue
    fi

    if [ -z "$fstype" ]; then
        echo "No fstype for $name. Creating..."
        sudo mkfs -t ext4 "$name"
    fi

    if [ -z "$mountpoint" ]; then
        echo "No mountpoint for $name. Mounting to '/data'"
        sudo mkdir -p /data
        sudo mount "$name" /data
        
        # Create minecraft directories and set proper permissions
        sudo mkdir -p /data/minecraft/world
        sudo mkdir -p /data/minecraft/config
        sudo mkdir -p /data/minecraft/plugins
        sudo chown -R ubuntu:ubuntu /data/minecraft
        sudo chmod -R 755 /data/minecraft
    fi
done < <(lsblk -rpno NAME,FSTYPE,MOUNTPOINT)