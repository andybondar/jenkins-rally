#!/bin/bash -x

FLAVOR=m1.medium
IMAGE="Ubuntu 14.04 x64 LTS"

source openrc

boot_vm () {
# Update security group
/usr/bin/nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
/usr/bin/nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
/usr/bin/nova secgroup-add-rule default udp 1 65535 0.0.0.0/0

# Add keypair
nova keypair-add --pub-key rally_rsa_key.pub rally

# Get net id
NET_ID=`nova net-list | grep net04 | grep -v ext | awk '{print $2}'`

# Check if image(s) siutable for Rally_VM is(are) in glance
img_status=`glance image-list | grep  "${IMAGE}" | wc -l`
if [ "$img_status" -eq 0 ]; then
    echo "=== There isn't any siutable image in available"
    exit 1
fi

IMG_ID=`glance image-list | grep  "${IMAGE}" | head -1 | awk '{print $2}'`

# Boot VM
nova boot --flavor ${FLAVOR} --image ${IMG_ID} --nic net-id=${NET_ID} --security-groups default --key-name=rally Rally_VM

# Wait untill Rally_VM is ready
count=250
while [[ $count -ne 0 ]] ; do
    echo "=== Waiting when OpenStack env is operational.. left $count attempts"
    status=`nova show Rally_VM | grep status | awk '{print $4}'`
    if [ "$status" = "ACTIVE" ]; then
	echo "=== Rally_VM is $status"
	break
    fi
    if [ "$status" = "ERROR" ]; then
	echo "=== Error!"
	exit 1
    fi
    count=$((count - 1))
    sleep 30
done

if [ "$status" != "ACTIVE" ]; then
    echo "=== Rally_VM is not ready"
    exit 1
fi

#Create and assign floating ip
nova floating-ip-create net04_ext
floating_ip=`nova floating-ip-list | grep net04_ext | head -1 | awk '{print $2}'`
nova floating-ip-associate Rally_VM ${floating_ip}
sleep 5
nova list
}

get_vm_ip () {
vm_ip=`nova show Rally_VM | grep network | awk '{print $6}'`
echo $vm_ip
}

upload_test_image () {
m=`glance image-list | grep Test_Image_1 | wc -l`
if [ "$m" -eq 0 ]; then
    glance image-create --name Test_Image_1 --disk-format qcow2 --container-format bare --copy-from http://37.58.123.146:8080/images/other_images/test_image_1.qcow2 --is-public True --is-protected True
    count=250
    while [[ $count -ne 0 ]] ; do
	echo "=== Waiting when Test_Image_1 is uploaded.. left $count attempts"
	status=`glance image-list | grep Test_Image_1 | awk '{print $12}'`
	if [ "$status" = "active" ]; then
	    echo "=== Test_Image_1 is uploaded"
	    break
	fi
	if  [ "$status" = "error" ]; then
	    echo "=== Test_Image_1 upload failed"
	    break
	fi

	if  [ -z $status ]; then
	    echo "=== Test_Image_1 upload failed"
	    break
	fi

	count=$((count - 1))
	sleep 60
    done
else
    echo "=== Test_Image_1 is already uploaded"
fi

if  [ "$status" != "active" ]; then
    echo "=== Test_Image_1 upload failed"
    exit 1
fi

}


create_floating_subnet () {
echo "=== Create fake subnet for floating IPs"
neutron quota-update --floatingip=100000
neutron  quota-update --network 1000 --subnet 1000 --port 1000 --router 1000
neutron subnet-create net04_ext 101.0.0.0/16 --disable-dhcp --name rally
}

clear_env () {
echo "Clear env"
vm_ip=`nova show Rally_VM | grep network | awk '{print $6}'`
nova floating-ip-disassociate Rally_VM $vm_ip
sleep 5
nova floating-ip-delete $vm_ip
sleep 5
nova delete Rally_VM
sleep 20
nova secgroup-delete-rule default tcp 22 22 0.0.0.0/0
sleep 5
nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0
sleep 5
nova secgroup-delete-rule default udp 1 65535 0.0.0.0/0
sleep 5
nova keypair-delete rally
sleep 5
}

case "$1" in
    boot)
boot_vm
;;

    getip)
get_vm_ip
;;

    upload)
upload_test_image
;;

    floating)
create_floating_subnet
;;

    clear)
clear_env
;;

    *)
echo $"Usage: $0 {boot|getip|upload|clear|floating}"
exit 1

esac
