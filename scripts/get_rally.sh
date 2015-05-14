#!/bin/bash -x

sudo apt-get update
sudo apt-get install -y git
cd ~
git clone https://git.openstack.org/openstack/rally
cd rally
sed -i s/ASKCONFIRMATION=1/ASKCONFIRMATION=0/g install_rally.sh
sudo ./install_rally.sh
