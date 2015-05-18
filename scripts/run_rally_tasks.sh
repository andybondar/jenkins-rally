#!/bin/bash -x

actions=(nova.associate_floating_ip nova.boot_server total vm.attach_floating_ip vm.run_command_over_ssh vm.wait_for_ping vm.wait_for_ssh)

###
c=0
###
n=1
###


#source openrc

#rally -v task start samples/tasks/scenarios/nova/boot-and-delete.json > logs/boot_and_delete.log

rm -rf logs
mkdir -p logs

# TODO: run it 3 times, create 'json' report if test unsuccessfull
while [[ $n -le 3 ]]; do
    sudo rally -v task start samples/tasks/scenarios/vm/boot-runcommand.json > logs/boot-runcommand-${n}.log

    # Check if all operations are 100% succssfull
    # Create 'json' report if test unsuccessfull
    status=`cat logs/boot-runcommand-${n}.log | grep finished | wc -l`
    if [ "$status" -eq 0 ]; then
	echo "FAILURE, please refer to logs/boot-runcommand-${n}.log" >> logs/failure.log
	#exit 1
    else
	task_id=`cat logs/boot-runcommand-${n}.log | grep finished | awk '{print $2}' | awk -F":" '{print $1}'`

	# Save test report in html format
	rally task report ${task_id} --out logs/boot-runcommand-${n}.html

	for i in ${actions[@]}; do
	    success=`cat logs/boot-runcommand-${n}.log | grep $i | awk '{print $16}'`
	    if [ "$success" != "100.0%" ]; then
		c=$((c + 1))
	    fi
	done
	if [ "$c" -gt 0 ]; then
	    echo "MOS is unstable, save report in JSON format and go on"
	    rally task results ${task_id} > logs/boot-runcommand-${n}.json
	fi
    fi
    n=$((n+1))
done
# end of loop


if [ "$c" -eq 0 ]; then
    echo "=== Congrats! All actions are successful"
else
    echo "=== $c action(s) are not 100% successful, MOS is unstable" >> logs/failure.log
    #exit 1
fi
