#!/bin/bash -x

FLAVOR=m1.medium
IMAGE="Ubuntu 14.04 x64 LTS"
#NET_NAME=net04

source openrc
nova list
glance image-list

# Update security group
/usr/bin/nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
/usr/bin/nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
/usr/bin/nova secgroup-add-rule default udp 1 65535 0.0.0.0/0

# Add keypair
nova keypair-add --pub-key rally_rsa_key.pub rally

# Get net id
NET_ID=`nova net-list | grep net04 | grep -v ext | awk '{print $2}'`

# Boot VM
nova boot --flavor ${FLAVOR} --image "$IMAGE" --nic net-id=${NET_ID} --security-groups default --key-name=rally Rally_VM

# TODO: Insert 'while' to wait VM is ACTIVE
sleep 30

#Create and assign floating ip
nova floating-ip-create net04_ext
floating_ip=`nova floating-ip-list | grep net04_ext | head -1 | awk '{print $2}'`
nova floating-ip-associate Rally_VM ${floating_ip}

nova list