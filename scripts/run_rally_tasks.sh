#!/bin/bash -x
source openrc

rally -v task start samples/tasks/scenarios/nova/boot-and-delete.json > logs/boot_and_delete.log

# Download Test image with preinstalled cpulimit and iperf packages

image=`glance image-list | grep Test_Image_1 | wc -l`
if [ "$image" -eq 0 ]; then
    glance image-create --name Test_Image_1 --disk-format qcow2 --container-format bare --copy-from http://37.58.123.146:8080/images/other_images/test_image_1.qcow2 --is-public True --is-protected True
    n=120
    while [[ $n -ne 0 ]] ; do
	echo "=== Wait untill image is downloaded. $n attempts left."
	img=`glance image-list | grep Test_Image_1 | wc -l`
	if [ "$img" -gt 0 ]; then
	    status=`glance image-show Test_Image_1 | grep status | awk '{print $4}'`
	    if [ "$status" = "active" ]; then
		echo "=== 'Test_Image_1' image is uploaded to storage"
		break
	    fi
	fi
	let n=n-1
	sleep 60
    done
fi


rally -v task start samples/tasks/scenarios/vm/boot-runcommand.json > logs/boot-runcommand.log
