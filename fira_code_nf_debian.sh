#!/bin/bash

# Update the package list and install necessary packages
sudo apt-get update
sudo apt-get install -y curl unzip

# Create a temporary directory for downloading the font
temp_dir=$(mktemp -d)

# Download the Fira Code Nerd Font
curl -L -o "${temp_dir}/FiraCode.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"

# Unzip the font
unzip "${temp_dir}/FiraCode.zip" -d "${temp_dir}"

# Create the font directory if it does not exist
sudo mkdir -p /usr/local/share/fonts/nerd-fonts

# Copy the font files to the font directory
sudo cp "${temp_dir}"/*.ttf /usr/local/share/fonts/nerd-fonts

# Update the font cache
sudo fc-cache -fv

# Clean up the temporary directory
rm -rf "${temp_dir}"

echo "Fira Code Nerd Font has been successfully installed!"