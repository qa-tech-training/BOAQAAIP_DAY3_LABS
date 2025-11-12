#!/bin/bash
sudo apt-get update
sudo apt-get install -y unzip
wget https://releases.hashicorp.com/terraform/1.13.5/terraform_1.13.5_linux_amd64.zip
unzip terraform_1.13.5_linux_amd64.zip -d linux-amd64
sudo cp linux-amd64/terraform /usr/local/bin/terraform