#!/bin/bash -x

sudo apt-get update
sudo apt-get install -y git
cd ~
git clone https://git.openstack.org/openstack/rally
cd rally
sudo ./install_rally.sh -y
