#!/bin/bash

# Prompt user for operation
echo "Do you want to encrypt or decrypt? (E/D)"
read op

if [ "$op" == "E" ]; then
  # Encrypt
  echo "Enter path to file or folder:"
  read path
  echo "Enter passphrase:"
  read -s passphrase

  if [ -f "$path" ]; then
    # Encrypt file
    echo "$passphrase" | gpg --symmetric --yes --batch --cipher-algo AES256 --passphrase-fd 0 --output "$path.gpg" "$path"
    echo "Encryption successful! Encrypted file saved as $path.gpg"
  elif [ -d "$path" ]; then
    # Encrypt folder
    for file in "$path"/*; do
      echo "$passphrase" | gpg --symmetric --yes --batch --cipher-algo AES256 --passphrase-fd 0 --output "$file.gpg" "$file"
    done
  fi

elif [ "$op" == "D" ]; then
  # Decrypt
  echo "Enter path to file or folder:"
  read path
  echo "Enter passphrase:"
  read -s passphrase

  if [ -f "$path" ]; then
    # Decrypt file
    echo "$passphrase" | gpg --decrypt --yes --batch --cipher-algo AES256 --passphrase-fd 0 --output "${path%.gpg}" "$path"
    echo "Decryption successful! Decrypted file saved as ${path%.gpg}"
  elif [ -d "$path" ]; then
    # Decrypt folder
    for file in "$path"/*.gpg; do
      echo "$passphrase" | gpg --decrypt --yes --batch --cipher-algo AES256 --passphrase-fd 0 --output "${file%.gpg}" "$file"
    done
  fi

else
  echo "Invalid operation"
fi
