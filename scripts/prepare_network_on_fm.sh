#!/bin/bash -x

remote_ip='REMOTE_IP'

if [ "$remote_ip" = "REMOTE_IP" ]; then 
    echo "Remote IP is not defined"
    exit 1
fi

ip tun add rally mode gre remote ${remote_ip} local 198.11.208.34 ttl 255
ip link set rally up
ip addr add 101.1.0.2/30 dev rally
ip route add 101.0.0.0/16 via 101.1.0.1
