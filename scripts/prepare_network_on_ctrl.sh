#!/bin/bash -x

remote_ip='REMOTE_IP'

if [ "$remote_ip" = "REMOTE_IP" ]; then 
    echo "Remote IP is not defined"
    exit 1
fi

source openrc

neutron  quota-update --network 1000 --subnet 1000 --port 1000 --router 1000
neutron quota-update --floatingip=100000

neutron subnet-create net04_ext 101.0.0.0/16 --name rally_subnet --disable-dhcp
neutron router-interface-add router04 rally_subnet

for i in $(ip netns | grep qrouter)
do
    count=`ip netns exec $i ip ro | grep 192.168.111.0/24 | wc -l`
    if  [ "$count" -eq 1 ]; then
	ext_if=`ip netns exec ${i} ip ro | grep default | awk '{print $5}'`
	ext_ip=`ip netns exec ${i} ifconfig ${ext_if} | grep 'inet addr' | awk '{print $2}' | awk -F":" '{print $2}'`
	echo $ext_ip > ext_ip

	ip netns exec ${i} ip tun add rally mode gre remote ${remote_ip} local ${ext_ip} ttl 255
	ip netns exec ${i} ip link set rally up
	ip netns exec ${i} ip addr add 101.1.0.1/30 dev rally
    fi
done
