#!/bin/bash -x
source openrc

#rally -v task start samples/tasks/scenarios/nova/boot-and-delete.json > logs/boot_and_delete.log

rm -rf logs
mkdir -p logs

# TODO: run it 3 times, create 'json' report if test unsuccessfull
rally -v task start samples/tasks/scenarios/vm/boot-runcommand.json > logs/boot-runcommand.log

# Check if all operations are 100% succssfull
# Create 'json' report if test unsuccessfull
